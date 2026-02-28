import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES, truncateHead } from "@mariozechner/pi-coding-agent";
import { StringEnum } from "@mariozechner/pi-ai";
import { Type } from "@sinclair/typebox";
import { spawn } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import * as path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

type LspAction =
  | "status"
  | "diagnostics"
  | "definition"
  | "references"
  | "hover"
  | "symbols"
  | "rename"
  | "reload";

type LspParams = {
  action: LspAction;
  file?: string;
  files?: string[];
  line?: number;
  column?: number;
  query?: string;
  new_name?: string;
  apply?: boolean;
  include_declaration?: boolean;
};

type ExecResult = {
  stdout: string;
  stderr: string;
  code: number;
  killed: boolean;
};

const GO_MARKERS = ["go.mod", "go.work"];
const PY_MARKERS = [
  "pyproject.toml",
  "pyrightconfig.json",
  "requirements.txt",
  "setup.py",
  "setup.cfg",
  "Pipfile",
];
const TS_MARKERS = ["tsconfig.json", "jsconfig.json", "package.json"];
const BASH_FILENAMES = new Set([".bashrc", ".bash_profile", ".zshrc", ".zprofile"]);

function normalizeInputPath(input: string): string {
  let value = input.trim();

  // Remove common wrappers models sometimes include.
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'")) ||
    (value.startsWith("`") && value.endsWith("`"))
  ) {
    value = value.slice(1, -1).trim();
  }

  // Remove @-prefix used in prompts.
  if (value.startsWith("@")) {
    value = value.slice(1);
  }

  // Drop trailing punctuation if present.
  while (value.endsWith(",") || value.endsWith(".")) {
    value = value.slice(0, -1);
  }

  return value;
}

function resolvePathFromCwd(input: string, cwd: string): string {
  const normalized = normalizeInputPath(input);
  if (path.isAbsolute(normalized)) return normalized;
  return path.resolve(cwd, normalized);
}

function toPos(value: number | undefined): number {
  const n = Number(value ?? 1);
  if (!Number.isFinite(n)) return 1;
  return Math.max(1, Math.floor(n));
}

function joinOutput(result: ExecResult): string {
  return [result.stdout.trim(), result.stderr.trim()].filter(Boolean).join("\n").trim();
}

function formatWithTruncation(text: string): string {
  const truncated = truncateHead(text, {
    maxBytes: DEFAULT_MAX_BYTES,
    maxLines: DEFAULT_MAX_LINES,
  });

  if (!truncated.truncated) {
    return truncated.content;
  }

  return `${truncated.content}\n\n[Output truncated: ${truncated.outputLines} of ${truncated.totalLines} lines (${truncated.outputBytes} of ${truncated.totalBytes} bytes).]`;
}

function findCommandOnPath(command: string): string | undefined {
  const envPath = process.env.PATH ?? "";
  const pathParts = envPath.split(path.delimiter).filter(Boolean);
  const isWindows = process.platform === "win32";
  const candidates = isWindows ? [command, `${command}.exe`, `${command}.cmd`, `${command}.bat`] : [command];

  for (const part of pathParts) {
    for (const candidate of candidates) {
      const full = path.join(part, candidate);
      if (!existsSync(full)) continue;
      try {
        if (statSync(full).isFile()) return full;
      } catch {
        // no-op
      }
    }
  }

  return undefined;
}

function findLocalCommand(command: string, cwd: string): string | undefined {
  const isWindows = process.platform === "win32";
  const suffixes = isWindows ? ["", ".cmd", ".exe", ".bat"] : [""];
  const binDirs = ["node_modules/.bin", ".venv/bin", "venv/bin", ".env/bin"];

  let current = cwd;
  while (true) {
    for (const binDir of binDirs) {
      for (const suffix of suffixes) {
        const candidate = path.join(current, binDir, `${command}${suffix}`);
        if (!existsSync(candidate)) continue;
        try {
          if (statSync(candidate).isFile()) return candidate;
        } catch {
          // no-op
        }
      }
    }

    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }

  return undefined;
}

function findCommand(command: string, cwd: string): string | undefined {
  return findLocalCommand(command, cwd) ?? findCommandOnPath(command);
}

function findProjectRoot(startDir: string, markers: string[]): string | undefined {
  let current = path.resolve(startDir);
  while (true) {
    if (markers.some(marker => existsSync(path.join(current, marker)))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return undefined;
}

function dirHasTerraformFiles(dir: string): boolean {
  try {
    return readdirSync(dir).some(name => name.endsWith(".tf"));
  } catch {
    return false;
  }
}

function findTerraformModuleRoot(startDir: string): string | undefined {
  let current = path.resolve(startDir);
  while (true) {
    if (dirHasTerraformFiles(current)) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return undefined;
}

type FileLanguage = "go" | "python" | "typescript" | "bash" | "lua" | "terraform" | "unknown";

function detectLanguage(filePath: string): FileLanguage {
  const ext = path.extname(filePath).toLowerCase();
  const base = path.basename(filePath).toLowerCase();

  if (ext === ".go") return "go";
  if (ext === ".py" || ext === ".pyi") return "python";
  if ([".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".mts", ".cts"].includes(ext)) return "typescript";
  if (ext === ".lua") return "lua";
  if (ext === ".tf" || ext === ".tfvars" || ext === ".hcl") return "terraform";
  if (ext === ".sh" || ext === ".bash" || ext === ".zsh" || BASH_FILENAMES.has(base)) return "bash";

  return "unknown";
}

function formatPyrightOutput(output: string, cwd: string): string {
  try {
    const parsed = JSON.parse(output) as {
      generalDiagnostics?: Array<{
        file?: string;
        severity?: string;
        message?: string;
        range?: { start?: { line?: number; character?: number } };
      }>;
      summary?: {
        filesAnalyzed?: number;
        errorCount?: number;
        warningCount?: number;
        informationCount?: number;
      };
    };

    const diagnostics = parsed.generalDiagnostics ?? [];
    if (diagnostics.length === 0) {
      return "No diagnostics";
    }

    const lines: string[] = [];
    const summary = parsed.summary;
    if (summary) {
      lines.push(
        `Pyright summary: ${summary.errorCount ?? 0} error(s), ${summary.warningCount ?? 0} warning(s), ${summary.informationCount ?? 0} info, ${summary.filesAnalyzed ?? 0} file(s) analyzed`,
      );
      lines.push("");
    }

    for (const diag of diagnostics) {
      const file = diag.file ? path.relative(cwd, diag.file) : "<unknown>";
      const line = (diag.range?.start?.line ?? 0) + 1;
      const column = (diag.range?.start?.character ?? 0) + 1;
      const severity = (diag.severity ?? "error").toUpperCase();
      const message = diag.message ?? "Unknown diagnostic";
      lines.push(`${severity} ${file}:${line}:${column} - ${message}`);
    }

    return lines.join("\n");
  } catch {
    return output.trim() || "No diagnostics";
  }
}

function normalizeTerraformFilename(filename: string, moduleRoot: string): string {
  if (path.isAbsolute(filename)) return path.resolve(filename);
  return path.resolve(moduleRoot, filename);
}

function formatTerraformValidateOutput(output: string, moduleRoot: string, targetFile?: string): string {
  try {
    const parsed = JSON.parse(output) as {
      valid?: boolean;
      error_count?: number;
      warning_count?: number;
      diagnostics?: Array<{
        severity?: string;
        summary?: string;
        detail?: string;
        range?: {
          filename?: string;
          start?: { line?: number; column?: number };
        };
      }>;
    };

    const allDiagnostics = parsed.diagnostics ?? [];
    const filteredDiagnostics =
      targetFile === undefined
        ? allDiagnostics
        : allDiagnostics.filter(diag => {
            const filename = diag.range?.filename;
            if (!filename) return false;
            return normalizeTerraformFilename(filename, moduleRoot) === targetFile;
          });

    const diagnostics = filteredDiagnostics;
    if (diagnostics.length === 0) {
      if (targetFile) return "No diagnostics for target file";
      return parsed.valid === true ? "No diagnostics" : "No diagnostics";
    }

    const lines: string[] = [];
    if (!targetFile) {
      lines.push(
        `Terraform validate summary: ${parsed.error_count ?? 0} error(s), ${parsed.warning_count ?? 0} warning(s), valid=${Boolean(parsed.valid)}`,
      );
      lines.push("");
    }

    for (const diag of diagnostics) {
      const severity = (diag.severity ?? "error").toUpperCase();
      const summary = diag.summary ?? "Terraform issue";
      const detail = diag.detail ?? "";
      const file = diag.range?.filename ?? "<unknown>";
      const line = diag.range?.start?.line ?? 1;
      const column = diag.range?.start?.column ?? 1;
      const location = `${file}:${line}:${column}`;
      lines.push(`${severity} ${location} - ${summary}${detail ? `: ${detail}` : ""}`);
    }

    return lines.join("\n");
  } catch {
    return output.trim() || "No diagnostics";
  }
}

function formatStatus(cwd: string): string {
  const gopls = findCommand("gopls", cwd);
  const go = findCommand("go", cwd);
  const pyright = findCommand("pyright", cwd);
  const pyrightLangserver = findCommand("pyright-langserver", cwd);
  const tsc = findCommand("tsc", cwd);
  const shellcheck = findCommand("shellcheck", cwd);
  const bashLanguageServer = findCommand("bash-language-server", cwd);
  const luaLanguageServer = findCommand("lua-language-server", cwd);
  const luacheck = findCommand("luacheck", cwd);
  const stylua = findCommand("stylua", cwd);
  const terraform = findCommand("terraform", cwd);
  const tflint = findCommand("tflint", cwd);

  const goRoot = findProjectRoot(cwd, GO_MARKERS);
  const pyRoot = findProjectRoot(cwd, PY_MARKERS);
  const tsRoot = findProjectRoot(cwd, TS_MARKERS);
  const tfRoot = findTerraformModuleRoot(cwd);

  const lines = [
    "lsp-lite status",
    "",
    "Commands:",
    `  gopls: ${gopls ?? "not found"}`,
    `  go: ${go ?? "not found"}`,
    `  pyright: ${pyright ?? "not found"}`,
    `  pyright-langserver: ${pyrightLangserver ?? "not found"}`,
    `  tsc: ${tsc ?? "not found"}`,
    `  shellcheck: ${shellcheck ?? "not found"}`,
    `  bash-language-server: ${bashLanguageServer ?? "not found"}`,
    `  lua-language-server: ${luaLanguageServer ?? "not found"}`,
    `  luacheck: ${luacheck ?? "not found"}`,
    `  stylua: ${stylua ?? "not found"}`,
    `  terraform: ${terraform ?? "not found"}`,
    `  tflint: ${tflint ?? "not found"}`,
    "",
    "Detected roots:",
    `  Go: ${goRoot ?? "not detected"}`,
    `  Python: ${pyRoot ?? "not detected"}`,
    `  TypeScript/JS: ${tsRoot ?? "not detected"}`,
    `  Terraform module: ${tfRoot ?? "not detected"}`,
    "",
    "Supported actions:",
    "  diagnostics: Go, Python, Bash, TypeScript/JavaScript, Lua, Terraform",
    "  definition/references/hover/symbols/rename:",
    "    - Go (via gopls)",
    "    - Python/TypeScript-JavaScript/Bash/Lua/Terraform (via stdio language servers; server capability dependent)",
  ];

  return lines.join("\n");
}

async function runCommand(
  pi: ExtensionAPI,
  command: string,
  args: string[],
  cwd: string,
  signal?: AbortSignal,
): Promise<ExecResult> {
  const result = await pi.exec(command, args, {
    cwd,
    signal,
    timeout: 120000,
  });

  return {
    stdout: result.stdout,
    stderr: result.stderr,
    code: result.code,
    killed: result.killed,
  };
}

async function diagnosticsForFile(
  pi: ExtensionAPI,
  filePath: string,
  cwd: string,
  signal?: AbortSignal,
): Promise<{ text: string; isError: boolean }> {
  const language = detectLanguage(filePath);

  if (language === "go") {
    const gopls = findCommand("gopls", cwd);
    const go = findCommand("go", cwd);
    if (!gopls && !go) {
      return {
        text: "Go diagnostics unavailable: neither gopls nor go found.",
        isError: true,
      };
    }

    const fileDir = path.dirname(filePath);
    const goRoot = findProjectRoot(fileDir, GO_MARKERS) ?? fileDir;

    let output = "";
    let used = "none";

    // Prefer gopls check for LSP-like diagnostics.
    if (gopls) {
      const primary = await runCommand(pi, gopls, ["check", filePath], goRoot, signal);
      output = joinOutput(primary);
      if (output) {
        used = "gopls";
      } else if (fileDir !== goRoot) {
        const retry = await runCommand(pi, gopls, ["check", filePath], fileDir, signal);
        output = joinOutput(retry);
        if (output) {
          used = "gopls";
        }
      }
    }

    // gopls can return no output under non-tty execution in some environments.
    // Fall back to `go build` for deterministic diagnostics.
    if (!output && go) {
      const build = await runCommand(pi, go, ["build"], fileDir, signal);
      output = joinOutput(build);
      if (output) {
        used = "go build";
      }
    }

    const text = output || "No diagnostics";
    const hasDiagnostics = text !== "No diagnostics";
    const sourceSuffix = used === "none" ? "" : ` [source: ${used}]`;

    return {
      text: `Diagnostics (${path.relative(cwd, filePath)} - Go${sourceSuffix}):\n${text}`,
      isError: hasDiagnostics,
    };
  }

  if (language === "python") {
    const pyright = findCommand("pyright", cwd);
    if (!pyright) {
      return {
        text: "Python diagnostics unavailable: pyright not found.",
        isError: true,
      };
    }

    const pyRoot = findProjectRoot(path.dirname(filePath), PY_MARKERS) ?? cwd;
    const result = await runCommand(pi, pyright, ["--outputjson", filePath], pyRoot, signal);
    const output = formatPyrightOutput(joinOutput(result), pyRoot);

    return {
      text: `Diagnostics (${path.relative(cwd, filePath)} - Python):\n${output}`,
      isError: result.code !== 0 && output !== "No diagnostics",
    };
  }

  if (language === "typescript") {
    const tsc = findCommand("tsc", cwd);
    if (!tsc) {
      return {
        text: "TypeScript/JavaScript diagnostics unavailable: tsc not found.",
        isError: true,
      };
    }

    const tsRoot = findProjectRoot(path.dirname(filePath), TS_MARKERS) ?? cwd;
    const hasProjectConfig =
      existsSync(path.join(tsRoot, "tsconfig.json")) || existsSync(path.join(tsRoot, "jsconfig.json"));
    const args = hasProjectConfig
      ? ["--noEmit", "--pretty", "false", "--project", tsRoot]
      : ["--noEmit", "--pretty", "false", filePath];

    const result = await runCommand(pi, tsc, args, tsRoot, signal);
    const output = joinOutput(result) || "No diagnostics";

    return {
      text: `Diagnostics (${path.relative(cwd, filePath)} - TypeScript/JavaScript):\n${output}`,
      isError: result.code !== 0 && output !== "No diagnostics",
    };
  }

  if (language === "bash") {
    const shellcheck = findCommand("shellcheck", cwd);
    if (!shellcheck) {
      return {
        text: "Bash diagnostics unavailable: shellcheck not found.",
        isError: true,
      };
    }

    const result = await runCommand(pi, shellcheck, ["-f", "gcc", filePath], cwd, signal);
    const output = joinOutput(result) || "No diagnostics";

    return {
      text: `Diagnostics (${path.relative(cwd, filePath)} - Bash):\n${output}`,
      isError: result.code !== 0 && output !== "No diagnostics",
    };
  }

  if (language === "lua") {
    const luacheck = findCommand("luacheck", cwd);
    if (!luacheck) {
      return {
        text: "Lua diagnostics unavailable: luacheck not found.",
        isError: true,
      };
    }

    const luacheckResult = await runCommand(pi, luacheck, ["--formatter", "plain", filePath], cwd, signal);
    const luacheckText = joinOutput(luacheckResult) || "No diagnostics";

    const stylua = findCommand("stylua", cwd);
    let styluaText = "";
    let styluaError = false;
    if (stylua) {
      const styluaResult = await runCommand(pi, stylua, ["--check", filePath], cwd, signal);
      const output = joinOutput(styluaResult);
      if (output) {
        styluaText = `Stylua check:\n${output}`;
      }
      styluaError = styluaResult.code !== 0;
    }

    const chunks = [`Diagnostics (${path.relative(cwd, filePath)} - Lua):\n${luacheckText}`];
    if (styluaText) chunks.push(styluaText);

    return {
      text: chunks.join("\n\n"),
      isError: (luacheckResult.code !== 0 && luacheckText !== "No diagnostics") || styluaError,
    };
  }

  if (language === "terraform") {
    const terraform = findCommand("terraform", cwd);
    if (!terraform) {
      return {
        text: "Terraform diagnostics unavailable: terraform not found.",
        isError: true,
      };
    }

    const moduleRoot = findTerraformModuleRoot(path.dirname(filePath)) ?? path.dirname(filePath);
    const validateResult = await runCommand(pi, terraform, ["validate", "-json"], moduleRoot, signal);
    const validateText = formatTerraformValidateOutput(joinOutput(validateResult), moduleRoot, filePath);

    const chunks = [
      `Diagnostics (${path.relative(cwd, filePath)} - Terraform):\n${validateText}`,
    ];

    let hasError = validateResult.code !== 0 && validateText !== "No diagnostics" && validateText !== "No diagnostics for target file";

    const tflint = findCommand("tflint", cwd);
    if (tflint) {
      const tflintResult = await runCommand(pi, tflint, ["--format", "compact"], moduleRoot, signal);
      const tflintText = joinOutput(tflintResult);
      if (tflintText) {
        chunks.push(`tflint:\n${tflintText}`);
      }
      if (tflintResult.code !== 0 && tflintText) {
        hasError = true;
      }
    }

    return {
      text: chunks.join("\n\n"),
      isError: hasError,
    };
  }

  return {
    text: `Diagnostics unavailable: unsupported file type for ${path.relative(cwd, filePath)}.`,
    isError: true,
  };
}

async function workspaceDiagnostics(
  pi: ExtensionAPI,
  cwd: string,
  signal?: AbortSignal,
): Promise<{ text: string; isError: boolean }> {
  const sections: string[] = [];
  let anyError = false;

  const pyRoot = findProjectRoot(cwd, PY_MARKERS);
  if (pyRoot) {
    const pyright = findCommand("pyright", pyRoot);
    if (pyright) {
      const result = await runCommand(pi, pyright, ["--outputjson"], pyRoot, signal);
      const output = formatPyrightOutput(joinOutput(result), pyRoot);
      sections.push(`Python workspace diagnostics (${pyRoot}):\n${output}`);
      if (result.code !== 0 && output !== "No diagnostics") anyError = true;
    }
  }

  const tsRoot = findProjectRoot(cwd, ["tsconfig.json", "jsconfig.json"]);
  if (tsRoot) {
    const tsc = findCommand("tsc", tsRoot);
    if (tsc) {
      const result = await runCommand(pi, tsc, ["--noEmit", "--pretty", "false", "--project", tsRoot], tsRoot, signal);
      const output = joinOutput(result) || "No diagnostics";
      sections.push(`TypeScript/JavaScript workspace diagnostics (${tsRoot}):\n${output}`);
      if (result.code !== 0 && output !== "No diagnostics") anyError = true;
    }
  }

  const tfRoot = findTerraformModuleRoot(cwd);
  if (tfRoot) {
    const terraform = findCommand("terraform", tfRoot);
    if (terraform) {
      const validateResult = await runCommand(pi, terraform, ["validate", "-json"], tfRoot, signal);
      const validateOutput = formatTerraformValidateOutput(joinOutput(validateResult), tfRoot);
      sections.push(`Terraform workspace diagnostics (${tfRoot}):\n${validateOutput}`);
      if (validateResult.code !== 0 && validateOutput !== "No diagnostics") anyError = true;
    }

    const tflint = findCommand("tflint", tfRoot);
    if (tflint) {
      const tflintResult = await runCommand(pi, tflint, ["--format", "compact"], tfRoot, signal);
      const tflintOutput = joinOutput(tflintResult);
      if (tflintOutput) {
        sections.push(`tflint (${tfRoot}):\n${tflintOutput}`);
      }
      if (tflintResult.code !== 0 && tflintOutput) anyError = true;
    }
  }

  const goRoot = findProjectRoot(cwd, GO_MARKERS);
  if (goRoot) {
    const go = findCommand("go", goRoot);
    if (go) {
      const result = await runCommand(pi, go, ["build", "./..."], goRoot, signal);
      const output = joinOutput(result) || "No diagnostics";
      sections.push(`Go workspace diagnostics (${goRoot} - go build ./...):\n${output}`);
      if (result.code !== 0 && output !== "No diagnostics") anyError = true;
    } else {
      sections.push(`Go workspace diagnostics (${goRoot}): go command not found.`);
      anyError = true;
    }
  }

  if (sections.length === 0) {
    return {
      text: "No supported workspace diagnostics available. Provide file=... for Go, Python, Bash, TypeScript/JavaScript, Lua, or Terraform diagnostics.",
      isError: true,
    };
  }

  return {
    text: sections.join("\n\n"),
    isError: anyError,
  };
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  if (!value || typeof value !== "object") return undefined;
  return value as Record<string, unknown>;
}

type LspPosition = { line: number; character: number };
type LspRange = { start: LspPosition; end: LspPosition };
type LspTextEdit = { range: LspRange; newText: string };

type NormalizedWorkspaceEdit = {
  filePath: string;
  edits: LspTextEdit[];
};

type LspServerSpec = {
  serverName: string;
  command: string;
  args: string[];
  rootDir: string;
  rootUri: string;
  languageId: string;
};

type LspCapabilityKey =
  | "definitionProvider"
  | "referencesProvider"
  | "hoverProvider"
  | "documentSymbolProvider"
  | "workspaceSymbolProvider"
  | "renameProvider";

type LspRequestInput = {
  spec: LspServerSpec;
  method: string;
  params: Record<string, unknown>;
  document?: {
    uri: string;
    languageId: string;
    text: string;
  };
  requiredCapability?: LspCapabilityKey;
  signal?: AbortSignal;
  timeoutMs?: number;
};

type LspRequestOutput = {
  result: unknown;
  capabilities: Record<string, unknown>;
  stderr: string;
};

const LSP_SYMBOL_KIND_NAMES: Record<number, string> = {
  1: "File",
  2: "Module",
  3: "Namespace",
  4: "Package",
  5: "Class",
  6: "Method",
  7: "Property",
  8: "Field",
  9: "Constructor",
  10: "Enum",
  11: "Interface",
  12: "Function",
  13: "Variable",
  14: "Constant",
  15: "String",
  16: "Number",
  17: "Boolean",
  18: "Array",
  19: "Object",
  20: "Key",
  21: "Null",
  22: "EnumMember",
  23: "Struct",
  24: "Event",
  25: "Operator",
  26: "TypeParameter",
};

function toFileUri(filePath: string): string {
  return pathToFileURL(filePath).toString();
}

function fromFileUri(uri: string): string | undefined {
  if (!uri.startsWith("file://")) return undefined;
  try {
    return fileURLToPath(uri);
  } catch {
    return undefined;
  }
}

function toLspPosition(line: number, column: number): LspPosition {
  return {
    line: Math.max(0, line - 1),
    character: Math.max(0, column - 1),
  };
}

function toLspLanguageId(language: FileLanguage, filePath: string): string {
  if (language === "typescript") {
    const ext = path.extname(filePath).toLowerCase();
    if ([".js", ".jsx", ".mjs", ".cjs"].includes(ext)) return "javascript";
    return "typescript";
  }
  if (language === "python") return "python";
  if (language === "bash") return "shellscript";
  if (language === "lua") return "lua";
  if (language === "terraform") return "terraform";
  if (language === "go") return "go";
  return "plaintext";
}

function methodRequiredCapability(method: string): LspCapabilityKey | undefined {
  if (method === "textDocument/definition") return "definitionProvider";
  if (method === "textDocument/references") return "referencesProvider";
  if (method === "textDocument/hover") return "hoverProvider";
  if (method === "textDocument/documentSymbol") return "documentSymbolProvider";
  if (method === "workspace/symbol") return "workspaceSymbolProvider";
  if (method === "textDocument/rename") return "renameProvider";
  return undefined;
}

function capabilityEnabled(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  return value !== undefined && value !== null;
}

function hasLspCapability(capabilities: Record<string, unknown>, capability: LspCapabilityKey): boolean {
  return capabilityEnabled(capabilities[capability]);
}

function capabilityLabel(capability: LspCapabilityKey): string {
  return capability;
}

const LSP_NOISE_LINE_PATTERNS = [/^workspace loading:/i, /^loading workspace:/i];

function normalizeLspText(text: string): string {
  const filtered = text
    .split(/\r?\n/)
    .map(line => line.trimEnd())
    .filter(line => !LSP_NOISE_LINE_PATTERNS.some(pattern => pattern.test(line.trim())));

  const compact: string[] = [];
  let previousBlank = false;

  for (const line of filtered) {
    const isBlank = line.trim().length === 0;
    if (isBlank) {
      if (previousBlank) continue;
      previousBlank = true;
      compact.push("");
    } else {
      previousBlank = false;
      compact.push(line);
    }
  }

  return compact.join("\n").trim();
}

function lspUnsupportedCapabilityError(capability: LspCapabilityKey): string {
  return `LSP_CAPABILITY_UNSUPPORTED:${capability}`;
}

function parseUnsupportedCapability(message: string): LspCapabilityKey | undefined {
  const prefix = "LSP_CAPABILITY_UNSUPPORTED:";
  if (!message.startsWith(prefix)) return undefined;
  const value = message.slice(prefix.length) as LspCapabilityKey;
  if (!value) return undefined;
  return value;
}

function lspSymbolKindName(kind: number | undefined): string {
  if (!kind || !LSP_SYMBOL_KIND_NAMES[kind]) return "Symbol";
  return LSP_SYMBOL_KIND_NAMES[kind];
}

function formatRange(range: LspRange | undefined): string {
  if (!range) return "?:?-?:?";
  return `${range.start.line + 1}:${range.start.character + 1}-${range.end.line + 1}:${range.end.character + 1}`;
}

function formatLocationLines(result: unknown, cwd: string): string {
  const lines: string[] = [];
  const seen = new Set<string>();

  const addLocation = (uri: unknown, range: unknown) => {
    if (typeof uri !== "string") return;
    const filePath = fromFileUri(uri);
    if (!filePath) return;

    const rangeRecord = asRecord(range);
    const start = asRecord(rangeRecord?.start);
    const end = asRecord(rangeRecord?.end);
    if (!start || !end) return;

    const parsedRange: LspRange = {
      start: {
        line: Number(start.line ?? 0),
        character: Number(start.character ?? 0),
      },
      end: {
        line: Number(end.line ?? 0),
        character: Number(end.character ?? 0),
      },
    };

    const rel = path.relative(cwd, filePath) || filePath;
    const formatted = `${rel}:${formatRange(parsedRange)}`;
    if (seen.has(formatted)) return;
    seen.add(formatted);
    lines.push(formatted);
  };

  const parseItem = (item: unknown) => {
    const record = asRecord(item);
    if (!record) return;

    // Location
    if (typeof record.uri === "string" && record.range) {
      addLocation(record.uri, record.range);
      return;
    }

    // LocationLink
    if (typeof record.targetUri === "string" && record.targetRange) {
      addLocation(record.targetUri, record.targetRange);
    }
  };

  if (Array.isArray(result)) {
    for (const item of result) parseItem(item);
  } else {
    parseItem(result);
  }

  if (lines.length === 0) return "No locations found";
  const text = normalizeLspText(lines.join("\n"));
  return text || "No locations found";
}

function hoverContentToText(value: unknown): string {
  if (typeof value === "string") return value.trim();

  if (Array.isArray(value)) {
    const parts = value.map(hoverContentToText).filter(Boolean);
    return parts.join("\n\n").trim();
  }

  const record = asRecord(value);
  if (!record) return "";

  if (typeof record.value === "string") {
    if (typeof record.language === "string" && record.language.trim()) {
      return `${record.language}\n${record.value}`.trim();
    }
    return record.value.trim();
  }

  return "";
}

function formatHoverResult(result: unknown): string {
  const hover = asRecord(result);
  if (!hover) return "No hover information";

  const text = normalizeLspText(hoverContentToText(hover.contents));
  return text || "No hover information";
}

function formatSymbolsResult(result: unknown): string {
  if (!Array.isArray(result) || result.length === 0) {
    return "No symbols";
  }

  const lines: string[] = [];

  const appendDocumentSymbol = (symbol: Record<string, unknown>) => {
    const name = typeof symbol.name === "string" ? symbol.name : "<unnamed>";
    const kind = lspSymbolKindName(Number(symbol.kind ?? 0));

    const rangeRecord = asRecord(symbol.selectionRange) ?? asRecord(symbol.range);
    const start = asRecord(rangeRecord?.start);
    const end = asRecord(rangeRecord?.end);

    const rangeText =
      start && end
        ? `${Number(start.line ?? 0) + 1}:${Number(start.character ?? 0) + 1}-${Number(end.line ?? 0) + 1}:${Number(end.character ?? 0) + 1}`
        : "?:?-?:?";

    lines.push(`${name} ${kind} ${rangeText}`);

    const children = Array.isArray(symbol.children) ? symbol.children : [];
    for (const child of children) {
      const childRecord = asRecord(child);
      if (childRecord) appendDocumentSymbol(childRecord);
    }
  };

  for (const item of result) {
    const record = asRecord(item);
    if (!record) continue;

    // SymbolInformation
    if (record.location) {
      const location = asRecord(record.location);
      const range = asRecord(location?.range);
      const start = asRecord(range?.start);
      const end = asRecord(range?.end);
      const name = typeof record.name === "string" ? record.name : "<unnamed>";
      const kind = lspSymbolKindName(Number(record.kind ?? 0));
      const rangeText =
        start && end
          ? `${Number(start.line ?? 0) + 1}:${Number(start.character ?? 0) + 1}-${Number(end.line ?? 0) + 1}:${Number(end.character ?? 0) + 1}`
          : "?:?-?:?";
      lines.push(`${name} ${kind} ${rangeText}`);
      continue;
    }

    // DocumentSymbol
    appendDocumentSymbol(record);
  }

  if (lines.length === 0) return "No symbols";
  const text = normalizeLspText(lines.join("\n"));
  return text || "No symbols";
}

function positionToOffset(text: string, position: LspPosition): number {
  const targetLine = Math.max(0, position.line);
  const targetCharacter = Math.max(0, position.character);

  let line = 0;
  let offset = 0;

  while (line < targetLine && offset < text.length) {
    const nextNewline = text.indexOf("\n", offset);
    if (nextNewline === -1) {
      return text.length;
    }
    offset = nextNewline + 1;
    line += 1;
  }

  return Math.min(text.length, offset + targetCharacter);
}

function compareEditsDesc(a: LspTextEdit, b: LspTextEdit): number {
  if (a.range.start.line !== b.range.start.line) {
    return b.range.start.line - a.range.start.line;
  }
  if (a.range.start.character !== b.range.start.character) {
    return b.range.start.character - a.range.start.character;
  }
  if (a.range.end.line !== b.range.end.line) {
    return b.range.end.line - a.range.end.line;
  }
  return b.range.end.character - a.range.end.character;
}

function normalizeTextEdit(value: unknown): LspTextEdit | undefined {
  const record = asRecord(value);
  if (!record) return undefined;
  const range = asRecord(record.range);
  const start = asRecord(range?.start);
  const end = asRecord(range?.end);
  const newText = typeof record.newText === "string" ? record.newText : undefined;
  if (!start || !end || newText === undefined) return undefined;

  return {
    range: {
      start: {
        line: Number(start.line ?? 0),
        character: Number(start.character ?? 0),
      },
      end: {
        line: Number(end.line ?? 0),
        character: Number(end.character ?? 0),
      },
    },
    newText,
  };
}

function normalizeWorkspaceEdits(workspaceEdit: unknown): NormalizedWorkspaceEdit[] {
  const record = asRecord(workspaceEdit);
  if (!record) return [];

  const byFile = new Map<string, LspTextEdit[]>();

  const push = (uri: string, edits: LspTextEdit[]) => {
    const filePath = fromFileUri(uri);
    if (!filePath || edits.length === 0) return;
    const existing = byFile.get(filePath) ?? [];
    existing.push(...edits);
    byFile.set(filePath, existing);
  };

  const changes = asRecord(record.changes);
  if (changes) {
    for (const [uri, rawEdits] of Object.entries(changes)) {
      if (!Array.isArray(rawEdits)) continue;
      const edits = rawEdits.map(normalizeTextEdit).filter((edit): edit is LspTextEdit => Boolean(edit));
      push(uri, edits);
    }
  }

  const documentChanges = Array.isArray(record.documentChanges) ? record.documentChanges : [];
  for (const change of documentChanges) {
    const changeRecord = asRecord(change);
    if (!changeRecord) continue;

    const textDocument = asRecord(changeRecord.textDocument);
    const uri = typeof textDocument?.uri === "string" ? textDocument.uri : undefined;
    if (!uri) continue;

    const rawEdits = Array.isArray(changeRecord.edits) ? changeRecord.edits : [];
    const edits = rawEdits.map(normalizeTextEdit).filter((edit): edit is LspTextEdit => Boolean(edit));
    push(uri, edits);
  }

  return [...byFile.entries()].map(([filePath, edits]) => ({
    filePath,
    edits: edits.sort(compareEditsDesc),
  }));
}

function applyTextEdits(content: string, edits: LspTextEdit[]): { updated: string; previews: string[]; applied: number } {
  let updated = content;
  const previews: string[] = [];
  let applied = 0;

  for (const edit of edits) {
    const start = positionToOffset(updated, edit.range.start);
    const end = positionToOffset(updated, edit.range.end);
    if (start > end) continue;

    const oldText = updated.slice(start, end);
    updated = `${updated.slice(0, start)}${edit.newText}${updated.slice(end)}`;

    const startLine = edit.range.start.line + 1;
    const startCol = edit.range.start.character + 1;
    previews.push(
      [`@@ ${startLine}:${startCol} @@`, `- ${JSON.stringify(oldText)}`, `+ ${JSON.stringify(edit.newText)}`].join("\n"),
    );
    applied += 1;
  }

  return { updated, previews: previews.reverse(), applied };
}

function applyWorkspaceRename(
  workspaceEdit: unknown,
  cwd: string,
  apply: boolean,
): { text: string; isError: boolean } {
  const normalized = normalizeWorkspaceEdits(workspaceEdit);
  if (normalized.length === 0) {
    return { text: "No rename edits returned by language server.", isError: false };
  }

  const output: string[] = [];
  let changedFiles = 0;
  let changedEdits = 0;
  let hasError = false;

  for (const item of normalized) {
    if (!existsSync(item.filePath)) {
      output.push(`Skipping ${item.filePath}: file not found.`);
      hasError = true;
      continue;
    }

    const before = readFileSync(item.filePath, "utf8");
    const { updated, previews, applied } = applyTextEdits(before, item.edits);

    if (before === updated) continue;

    changedFiles += 1;
    changedEdits += applied;

    if (apply) {
      writeFileSync(item.filePath, updated, "utf8");
      const rel = path.relative(cwd, item.filePath) || item.filePath;
      output.push(`${rel}: applied ${applied} edit(s)`);
    } else {
      output.push(`--- ${item.filePath}.orig`);
      output.push(`+++ ${item.filePath}`);
      output.push(previews.join("\n"));
      output.push("");
    }
  }

  if (apply) {
    const summary = `Applied rename edits to ${changedFiles} file(s), ${changedEdits} edit(s).`;
    return {
      text: output.length ? `${summary}\n${output.join("\n")}` : summary,
      isError: hasError,
    };
  }

  const previewText = output.join("\n").trim();
  return {
    text: previewText || "Rename produced no file changes.",
    isError: hasError,
  };
}

function formatLspError(error: unknown): string {
  const record = asRecord(error);
  if (!record) return "Unknown LSP error";

  const code = typeof record.code === "number" ? record.code : undefined;
  const message = typeof record.message === "string" ? record.message : "Unknown LSP error";
  const data = typeof record.data === "string" ? ` (${record.data})` : "";

  return `${code !== undefined ? `LSP ${code}: ` : ""}${message}${data}`;
}

function resolveLspServerForFile(filePath: string, cwd: string): { spec?: LspServerSpec; language: FileLanguage; error?: string } {
  const language = detectLanguage(filePath);
  const fileDir = path.dirname(filePath);

  if (language === "go" || language === "unknown") {
    return { language, error: "No non-Go LSP server configured for this file type." };
  }

  if (language === "python") {
    const command = findCommand("pyright-langserver", cwd);
    if (!command) {
      return { language, error: "Python code-intel unavailable: pyright-langserver not found." };
    }
    const rootDir = findProjectRoot(fileDir, PY_MARKERS) ?? fileDir;
    return {
      language,
      spec: {
        serverName: "pyright-langserver",
        command,
        args: ["--stdio"],
        rootDir,
        rootUri: toFileUri(rootDir),
        languageId: toLspLanguageId(language, filePath),
      },
    };
  }

  if (language === "typescript") {
    const command = findCommand("typescript-language-server", cwd);
    if (!command) {
      return { language, error: "TypeScript/JavaScript code-intel unavailable: typescript-language-server not found." };
    }
    const rootDir = findProjectRoot(fileDir, TS_MARKERS) ?? fileDir;
    return {
      language,
      spec: {
        serverName: "typescript-language-server",
        command,
        args: ["--stdio"],
        rootDir,
        rootUri: toFileUri(rootDir),
        languageId: toLspLanguageId(language, filePath),
      },
    };
  }

  if (language === "bash") {
    const command = findCommand("bash-language-server", cwd);
    if (!command) {
      return { language, error: "Bash code-intel unavailable: bash-language-server not found." };
    }
    const rootDir = findProjectRoot(fileDir, [".git"]) ?? fileDir;
    return {
      language,
      spec: {
        serverName: "bash-language-server",
        command,
        args: ["start"],
        rootDir,
        rootUri: toFileUri(rootDir),
        languageId: toLspLanguageId(language, filePath),
      },
    };
  }

  if (language === "lua") {
    const command = findCommand("lua-language-server", cwd) ?? findCommand("lua_ls", cwd);
    if (!command) {
      return { language, error: "Lua code-intel unavailable: lua-language-server not found." };
    }
    const rootDir = findProjectRoot(fileDir, [".luarc.json", ".luacheckrc", ".git"]) ?? fileDir;
    return {
      language,
      spec: {
        serverName: "lua-language-server",
        command,
        args: [],
        rootDir,
        rootUri: toFileUri(rootDir),
        languageId: toLspLanguageId(language, filePath),
      },
    };
  }

  if (language === "terraform") {
    const command = findCommand("terraform-ls", cwd);
    if (!command) {
      return { language, error: "Terraform code-intel unavailable: terraform-ls not found." };
    }
    const rootDir = findTerraformModuleRoot(fileDir) ?? fileDir;
    return {
      language,
      spec: {
        serverName: "terraform-ls",
        command,
        args: ["serve"],
        rootDir,
        rootUri: toFileUri(rootDir),
        languageId: toLspLanguageId(language, filePath),
      },
    };
  }

  return { language, error: "No LSP server configured for this file type." };
}

async function runLspRequest(input: LspRequestInput): Promise<LspRequestOutput> {
  const timeoutMs = input.timeoutMs ?? 45000;

  return await new Promise((resolve, reject) => {
    const proc = spawn(input.spec.command, input.spec.args, {
      cwd: input.spec.rootDir,
      stdio: ["pipe", "pipe", "pipe"],
    });

    let finished = false;
    let stderr = "";
    let capabilities: Record<string, unknown> = {};
    let nextId = 1;
    let stdoutBuffer = Buffer.alloc(0);

    const headerSeparator = Buffer.from("\r\n\r\n");

    const pending = new Map<
      number,
      {
        method: string;
        timer: ReturnType<typeof setTimeout>;
        resolve: (value: unknown) => void;
        reject: (error: Error) => void;
      }
    >();

    const done = (error?: Error, result?: unknown) => {
      if (finished) return;
      finished = true;

      for (const request of pending.values()) {
        clearTimeout(request.timer);
      }
      pending.clear();

      if (input.signal) {
        input.signal.removeEventListener("abort", onAbort);
      }

      if (!proc.killed) {
        proc.kill("SIGTERM");
        setTimeout(() => {
          if (!proc.killed) proc.kill("SIGKILL");
        }, 500).unref();
      }

      if (error) {
        reject(error);
      } else {
        resolve({ result, capabilities, stderr: stderr.trim() });
      }
    };

    const onAbort = () => {
      done(new Error("LSP request aborted"));
    };

    if (input.signal?.aborted) {
      done(new Error("LSP request aborted"));
      return;
    }

    if (input.signal) {
      input.signal.addEventListener("abort", onAbort, { once: true });
    }

    const writeMessage = (payload: Record<string, unknown>) => {
      const body = JSON.stringify(payload);
      const framed = `Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`;
      proc.stdin.write(framed, "utf8");
    };

    const sendNotification = (method: string, params: Record<string, unknown>) => {
      writeMessage({ jsonrpc: "2.0", method, params });
    };

    const sendRequest = (method: string, params: unknown, requestTimeoutMs = timeoutMs): Promise<unknown> => {
      return new Promise((resolveRequest, rejectRequest) => {
        const id = nextId++;
        const timer = setTimeout(() => {
          pending.delete(id);
          rejectRequest(new Error(`LSP request timed out: ${method}`));
        }, requestTimeoutMs);

        pending.set(id, {
          method,
          timer,
          resolve: resolveRequest,
          reject: rejectRequest,
        });

        writeMessage({ jsonrpc: "2.0", id, method, params });
      });
    };

    const handleMessage = (message: Record<string, unknown>) => {
      if (typeof message.id !== "number") return;
      const request = pending.get(message.id);
      if (!request) return;

      clearTimeout(request.timer);
      pending.delete(message.id);

      if (message.error) {
        request.reject(new Error(formatLspError(message.error)));
      } else {
        request.resolve(message.result);
      }
    };

    const parseStdout = () => {
      while (true) {
        const headerEnd = stdoutBuffer.indexOf(headerSeparator);
        if (headerEnd === -1) return;

        const headerText = stdoutBuffer.slice(0, headerEnd).toString("utf8");
        const contentLengthMatch = /Content-Length:\s*(\d+)/i.exec(headerText);
        if (!contentLengthMatch) {
          done(new Error("Invalid LSP response: missing Content-Length header"));
          return;
        }

        const contentLength = Number(contentLengthMatch[1]);
        const messageStart = headerEnd + headerSeparator.length;
        const messageEnd = messageStart + contentLength;
        if (stdoutBuffer.length < messageEnd) return;

        const bodyText = stdoutBuffer.slice(messageStart, messageEnd).toString("utf8");
        stdoutBuffer = stdoutBuffer.slice(messageEnd);

        try {
          const message = JSON.parse(bodyText) as unknown;
          const messageRecord = asRecord(message);
          if (messageRecord) handleMessage(messageRecord);
        } catch {
          done(new Error("Failed to parse LSP response JSON"));
          return;
        }
      }
    };

    proc.stdout.on("data", chunk => {
      stdoutBuffer = Buffer.concat([stdoutBuffer, chunk as Buffer]);
      parseStdout();
    });

    proc.stderr.on("data", chunk => {
      stderr += chunk.toString();
    });

    proc.on("error", err => {
      done(new Error(`Failed to start ${input.spec.serverName}: ${err.message}`));
    });

    proc.on("close", code => {
      if (finished) return;
      done(new Error(`${input.spec.serverName} exited before completing request (code=${code ?? 0})${stderr ? `\n${stderr.trim()}` : ""}`));
    });

    void (async () => {
      try {
        const initializeResult = await sendRequest("initialize", {
          processId: process.pid,
          rootUri: input.spec.rootUri,
          workspaceFolders: [
            {
              uri: input.spec.rootUri,
              name: path.basename(input.spec.rootDir),
            },
          ],
          capabilities: {},
        });

        const initRecord = asRecord(initializeResult);
        capabilities = asRecord(initRecord?.capabilities) ?? {};

        const requiredCapability = input.requiredCapability ?? methodRequiredCapability(input.method);
        if (requiredCapability && !hasLspCapability(capabilities, requiredCapability)) {
          throw new Error(lspUnsupportedCapabilityError(requiredCapability));
        }

        sendNotification("initialized", {});

        if (input.document) {
          sendNotification("textDocument/didOpen", {
            textDocument: {
              uri: input.document.uri,
              languageId: input.document.languageId,
              version: 1,
              text: input.document.text,
            },
          });
        }

        const result = await sendRequest(input.method, input.params, timeoutMs);

        if (input.document) {
          sendNotification("textDocument/didClose", {
            textDocument: {
              uri: input.document.uri,
            },
          });
        }

        try {
          await sendRequest("shutdown", null, 5000);
        } catch {
          // no-op
        }

        try {
          sendNotification("exit", {});
        } catch {
          // no-op
        }

        done(undefined, result);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        done(new Error(message));
      }
    })();
  });
}

function isMethodUnsupportedError(message: string): boolean {
  const normalized = message.toLowerCase();
  return (
    normalized.includes("method not found") ||
    normalized.includes("lsp -32601") ||
    normalized.includes("not supported") ||
    normalized.includes("unsupported")
  );
}

async function runGoSymbolAction(
  pi: ExtensionAPI,
  action: LspAction,
  params: LspParams,
  cwd: string,
  signal?: AbortSignal,
): Promise<{ text: string; isError: boolean; details: Record<string, unknown> }> {
  const gopls = findCommand("gopls", cwd);
  if (!gopls) {
    return {
      text: "gopls not found. Install gopls for Go symbol operations.",
      isError: true,
      details: { action, success: false },
    };
  }

  const requiresFile = action !== "symbols" || Boolean(params.file);
  const file = params.file ? resolvePathFromCwd(params.file, cwd) : undefined;

  if (requiresFile && !file) {
    return {
      text: "file parameter is required for this action.",
      isError: true,
      details: { action, success: false },
    };
  }

  const rootBase = file ? path.dirname(file) : cwd;
  const goRoot = findProjectRoot(rootBase, GO_MARKERS) ?? cwd;
  const line = toPos(params.line);
  const column = toPos(params.column);
  const position = file ? `${file}:${line}:${column}` : "";

  let args: string[] = [];

  if (action === "definition") {
    args = ["definition", position];
  } else if (action === "references") {
    args = ["references"];
    if (params.include_declaration ?? true) {
      args.push("-d");
    }
    args.push(position);
  } else if (action === "hover") {
    args = ["signature", position];
  } else if (action === "symbols") {
    if (file) {
      args = ["symbols", file];
    } else {
      if (!params.query?.trim()) {
        return {
          text: "query parameter is required for workspace symbols when file is omitted.",
          isError: true,
          details: { action, success: false },
        };
      }
      args = ["workspace_symbol", params.query.trim()];
    }
  } else if (action === "rename") {
    const newName = params.new_name?.trim();
    if (!newName) {
      return {
        text: "new_name parameter is required for rename.",
        isError: true,
        details: { action, success: false },
      };
    }
    args = ["rename"];
    if (params.apply === true) {
      args.push("-w", "-l");
    } else {
      args.push("-d");
    }
    args.push(position, newName);
  } else {
    return {
      text: `Unsupported action: ${action}`,
      isError: true,
      details: { action, success: false },
    };
  }

  const result = await runCommand(pi, gopls, args, goRoot, signal);
  const output = normalizeLspText(joinOutput(result)) || "No output";
  const success = result.code === 0 && !result.killed;

  return {
    text: output,
    isError: !success,
    details: { action, success, command: gopls, cwd: goRoot },
  };
}

async function runNonGoSymbolAction(
  action: LspAction,
  params: LspParams,
  filePath: string,
  cwd: string,
  signal?: AbortSignal,
): Promise<{ text: string; isError: boolean; details: Record<string, unknown> }> {
  const resolved = resolveLspServerForFile(filePath, cwd);
  if (!resolved.spec) {
    return {
      text: resolved.error ?? "Unable to resolve language server.",
      isError: true,
      details: { action, success: false },
    };
  }

  const documentUri = toFileUri(filePath);
  let documentText = "";
  try {
    documentText = readFileSync(filePath, "utf8");
  } catch (error) {
    return {
      text: `Failed to read file: ${filePath} (${error instanceof Error ? error.message : String(error)})`,
      isError: true,
      details: { action, success: false },
    };
  }

  const line = toPos(params.line);
  const column = toPos(params.column);
  const position = toLspPosition(line, column);

  let method = "";
  let requestParams: Record<string, unknown> = {};

  if (action === "definition") {
    method = "textDocument/definition";
    requestParams = {
      textDocument: { uri: documentUri },
      position,
    };
  } else if (action === "references") {
    method = "textDocument/references";
    requestParams = {
      textDocument: { uri: documentUri },
      position,
      context: {
        includeDeclaration: params.include_declaration ?? true,
      },
    };
  } else if (action === "hover") {
    method = "textDocument/hover";
    requestParams = {
      textDocument: { uri: documentUri },
      position,
    };
  } else if (action === "symbols") {
    method = "textDocument/documentSymbol";
    requestParams = {
      textDocument: { uri: documentUri },
    };
  } else if (action === "rename") {
    const newName = params.new_name?.trim();
    if (!newName) {
      return {
        text: "new_name parameter is required for rename.",
        isError: true,
        details: { action, success: false },
      };
    }

    method = "textDocument/rename";
    requestParams = {
      textDocument: { uri: documentUri },
      position,
      newName,
    };
  } else {
    return {
      text: `Unsupported action: ${action}`,
      isError: true,
      details: { action, success: false },
    };
  }

  try {
    const output = await runLspRequest({
      spec: resolved.spec,
      method,
      params: requestParams,
      document: {
        uri: documentUri,
        languageId: resolved.spec.languageId,
        text: documentText,
      },
      signal,
    });

    if (action === "definition" || action === "references") {
      return {
        text: formatLocationLines(output.result, cwd),
        isError: false,
        details: { action, success: true, command: resolved.spec.command, cwd: resolved.spec.rootDir },
      };
    }

    if (action === "hover") {
      return {
        text: formatHoverResult(output.result),
        isError: false,
        details: { action, success: true, command: resolved.spec.command, cwd: resolved.spec.rootDir },
      };
    }

    if (action === "symbols") {
      return {
        text: formatSymbolsResult(output.result),
        isError: false,
        details: { action, success: true, command: resolved.spec.command, cwd: resolved.spec.rootDir },
      };
    }

    if (action === "rename") {
      const renameResult = applyWorkspaceRename(output.result, cwd, params.apply === true);
      return {
        text: renameResult.text,
        isError: renameResult.isError,
        details: { action, success: !renameResult.isError, command: resolved.spec.command, cwd: resolved.spec.rootDir },
      };
    }

    return {
      text: "No output",
      isError: false,
      details: { action, success: true, command: resolved.spec.command, cwd: resolved.spec.rootDir },
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const capability = parseUnsupportedCapability(message);
    const unsupported = capability !== undefined || isMethodUnsupportedError(message);

    return {
      text: unsupported
        ? capability
          ? `${resolved.spec.serverName} reports ${capabilityLabel(capability)}=false; ${action} is not supported for ${resolved.language} files.`
          : `${resolved.spec.serverName} does not support ${action} for ${resolved.language} files.`
        : `${resolved.spec.serverName} ${action} failed: ${normalizeLspText(message) || message}`,
      isError: true,
      details: { action, success: false, command: resolved.spec.command, cwd: resolved.spec.rootDir },
    };
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "lsp",
    label: "LSP Lite",
    description:
      "Lightweight LSP-like tool for stock pi. Supports diagnostics for Python, Bash, Go, JavaScript/TypeScript, Lua, and Terraform; code intelligence via gopls (Go) and stdio language servers for non-Go languages.",
    parameters: Type.Object({
      action: StringEnum(["status", "diagnostics", "definition", "references", "hover", "symbols", "rename", "reload"] as const, {
        description: "LSP operation",
      }),
      file: Type.Optional(Type.String({ description: "File path" })),
      files: Type.Optional(Type.Array(Type.String({ description: "File path" }))),
      line: Type.Optional(Type.Number({ description: "Line number (1-indexed)" })),
      column: Type.Optional(Type.Number({ description: "Column number (1-indexed)" })),
      query: Type.Optional(Type.String({ description: "Workspace query for symbols" })),
      new_name: Type.Optional(Type.String({ description: "New symbol name for rename" })),
      apply: Type.Optional(Type.Boolean({ description: "Apply rename edits to files (default: false)" })),
      include_declaration: Type.Optional(Type.Boolean({ description: "Include declaration in references (default: true)" })),
    }),

    async execute(_toolCallId, rawParams, signal, _onUpdate, ctx) {
      const params = rawParams as LspParams;
      const action = params.action;

      if (action === "status") {
        const text = formatStatus(ctx.cwd);
        return {
          content: [{ type: "text", text: formatWithTruncation(text) }],
          details: { action, success: true },
        };
      }

      if (action === "reload") {
        return {
          content: [
            {
              type: "text",
              text: "lsp-lite does not keep persistent language-server sessions, so reload is a no-op.",
            },
          ],
          details: { action, success: true },
        };
      }

      if (action === "diagnostics") {
        const targets = params.files?.length ? params.files : params.file ? [params.file] : [];

        if (targets.length === 0) {
          const result = await workspaceDiagnostics(pi, ctx.cwd, signal);
          return {
            content: [{ type: "text", text: formatWithTruncation(result.text) }],
            details: { action, success: !result.isError },
            isError: result.isError,
          };
        }

        const outputs: string[] = [];
        let hasError = false;

        for (const target of targets) {
          const resolved = resolvePathFromCwd(target, ctx.cwd);
          const result = await diagnosticsForFile(pi, resolved, ctx.cwd, signal);
          outputs.push(result.text);
          if (result.isError) hasError = true;
        }

        const text = outputs.join("\n\n");
        return {
          content: [{ type: "text", text: formatWithTruncation(text) }],
          details: { action, success: !hasError },
          isError: hasError,
        };
      }

      const file = params.file ? resolvePathFromCwd(params.file, ctx.cwd) : undefined;

      if (action === "symbols" && !file) {
        const goResult = await runGoSymbolAction(pi, action, params, ctx.cwd, signal);
        return {
          content: [{ type: "text", text: formatWithTruncation(goResult.text) }],
          details: goResult.details,
          isError: goResult.isError,
        };
      }

      if (!file) {
        return {
          content: [{ type: "text", text: "file parameter is required for this action." }],
          details: { action, success: false },
          isError: true,
        };
      }

      const language = detectLanguage(file);

      if (language === "go") {
        const goResult = await runGoSymbolAction(pi, action, { ...params, file }, ctx.cwd, signal);
        return {
          content: [{ type: "text", text: formatWithTruncation(goResult.text) }],
          details: goResult.details,
          isError: goResult.isError,
        };
      }

      if (language === "unknown") {
        return {
          content: [{ type: "text", text: `Unsupported file type for action=${action}: ${path.relative(ctx.cwd, file)}` }],
          details: { action, success: false },
          isError: true,
        };
      }

      const nonGoResult = await runNonGoSymbolAction(action, params, file, ctx.cwd, signal);
      return {
        content: [{ type: "text", text: formatWithTruncation(nonGoResult.text) }],
        details: nonGoResult.details,
        isError: nonGoResult.isError,
      };
    },
  });
}
