import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const ASK_TOOL_NAMES = new Set(["ask", "AskUserQuestion"]);
const MUNG_TAG = "pi-agent";
const MUNG_ACTION_TAG = "pi-needs-action";
const DEFAULT_DONE_MESSAGE = "Pi finished this turn and is waiting for your input.";
const DEFAULT_ACTION_MESSAGE = "Pi needs your input in the current session.";
const ACTION_ICON = process.env.PI_MUNG_ACTION_ICON ?? "bell.badge.fill";
const LEGACY_ACTION_ICONS = new Set(["🦴", "🟡"]);
const UPDATE_ICON = process.env.PI_MUNG_UPDATE_ICON ?? "checkmark.circle.fill";
const HOME_DIR = process.env.HOME ?? "/Users/choru";
const FOCUS_SCRIPT_PATH = process.env.PI_MUNG_FOCUS_SCRIPT ?? `${HOME_DIR}/.pi/agent/scripts/mung-focus.sh`;

type ExecResult = {
  code: number;
  stdout: string;
  stderr: string;
  killed?: boolean;
};

function normalizeText(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 1))}…`;
}

function shellEscape(value: string): string {
  return `'${value.replace(/'/g, `'"'"'`)}'`;
}

function normalizeZellijPaneId(rawPaneId: string | undefined): string | undefined {
  if (!rawPaneId) return undefined;
  const trimmed = normalizeText(rawPaneId);
  if (!trimmed) return undefined;
  if (trimmed.startsWith("terminal_") || trimmed.startsWith("plugin_")) {
    return trimmed;
  }
  if (/^\d+$/.test(trimmed)) {
    return `terminal_${trimmed}`;
  }
  return trimmed;
}

function extractTextContent(content: unknown): string {
  if (!Array.isArray(content)) return "";

  const parts: string[] = [];
  for (const block of content) {
    if (!block || typeof block !== "object") continue;
    const typed = block as { type?: unknown; text?: unknown };
    if (typed.type === "text" && typeof typed.text === "string") {
      parts.push(typed.text);
    }
  }

  return normalizeText(parts.join(" "));
}

function extractLastAssistantText(messages: unknown): string | undefined {
  if (!Array.isArray(messages)) return undefined;

  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const message = messages[index];
    if (!message || typeof message !== "object") continue;

    const typed = message as { role?: unknown; content?: unknown };
    if (typed.role !== "assistant") continue;

    const text = extractTextContent(typed.content);
    if (text.length > 0) {
      return text;
    }
  }

  return undefined;
}

function looksLikeActionRequest(text: string | undefined): boolean {
  if (!text) return false;
  if (text.includes("?")) return true;

  return /\b(confirm|choose|select|provide|share|decide|input|approval|required|which|what|can you|please)\b/i.test(
    text,
  );
}

async function tryExec(pi: ExtensionAPI, command: string, args: string[]): Promise<ExecResult | null> {
  try {
    return (await pi.exec(command, args)) as ExecResult;
  } catch {
    return null;
  }
}

async function resolveMungCommand(pi: ExtensionAPI): Promise<string | undefined> {
  const candidates = ["mung", "/opt/homebrew/bin/mung"];

  for (const candidate of candidates) {
    const result = await tryExec(pi, candidate, ["version"]);
    if (result && result.code === 0) {
      return candidate;
    }
  }

  return undefined;
}

function hasTag(rawTags: unknown, expectedTag: string): boolean {
  if (!Array.isArray(rawTags)) return false;

  for (const tag of rawTags) {
    if (typeof tag === "string" && normalizeText(tag) === expectedTag) {
      return true;
    }
  }

  return false;
}

function isActionAlert(item: { icon?: unknown; title?: unknown; tags?: unknown }): boolean {
  if (hasTag(item.tags, MUNG_ACTION_TAG)) return true;

  const icon = typeof item.icon === "string" ? item.icon : "";
  if (icon === ACTION_ICON || LEGACY_ACTION_ICONS.has(icon)) return true;

  const title = typeof item.title === "string" ? item.title : "";
  return title === "Pi needs your action" || title === "Pi needs your confirmation";
}

async function listActionAlertIds(pi: ExtensionAPI, mungCommand: string): Promise<string[]> {
  const result = await tryExec(pi, mungCommand, ["list", "--tag", MUNG_TAG, "--json"]);
  if (!result || result.code !== 0) return [];

  let parsed: unknown;
  try {
    parsed = JSON.parse(result.stdout);
  } catch {
    return [];
  }

  if (!Array.isArray(parsed)) return [];

  const ids: string[] = [];
  for (const entry of parsed) {
    if (!entry || typeof entry !== "object") continue;

    const typedEntry = entry as { id?: unknown; icon?: unknown; title?: unknown; tags?: unknown };
    if (typeof typedEntry.id !== "string" || typedEntry.id.length === 0) continue;
    if (!isActionAlert(typedEntry)) continue;

    ids.push(typedEntry.id);
  }

  return ids;
}

async function cleanupActionAlerts(pi: ExtensionAPI, mungCommand: string): Promise<void> {
  const ids = await listActionAlertIds(pi, mungCommand);
  for (const id of ids) {
    await tryExec(pi, mungCommand, ["done", id]);
  }
}

function toolExecutionWasError(event: unknown): boolean {
  if (!event || typeof event !== "object") return false;
  return (event as { isError?: unknown }).isError === true;
}

function extractAskCancelledFlag(event: unknown): boolean | undefined {
  if (!event || typeof event !== "object") return undefined;

  const result = (event as { result?: unknown }).result;
  if (!result || typeof result !== "object") return undefined;

  const details = (result as { details?: unknown }).details;
  if (!details || typeof details !== "object") return undefined;

  const cancelled = (details as { cancelled?: unknown }).cancelled;
  if (typeof cancelled === "boolean") return cancelled;
  return undefined;
}

async function resolveFocusedZellijTabIndex(pi: ExtensionAPI, sessionName: string): Promise<number | undefined> {
  const result = await tryExec(pi, "/opt/homebrew/bin/zellij", ["-s", sessionName, "action", "dump-layout"]);
  if (!result || result.code !== 0) return undefined;

  let tabIndex = 0;
  for (const line of result.stdout.split(/\r?\n/)) {
    if (!/^\s*tab name=/.test(line)) continue;

    tabIndex += 1;
    if (line.includes("focus=true")) {
      return tabIndex;
    }
  }

  return undefined;
}

async function buildOnClickCommand(pi: ExtensionAPI): Promise<string | undefined> {
  const weztermPaneId = normalizeText(process.env.WEZTERM_PANE ?? "");
  const zellijSessionName = normalizeText(process.env.ZELLIJ_SESSION_NAME ?? "");
  const zellijPaneId = normalizeZellijPaneId(process.env.ZELLIJ_PANE_ID);

  if (!weztermPaneId && !zellijSessionName && !zellijPaneId) {
    return undefined;
  }

  const tabIndex = zellijSessionName
    ? await resolveFocusedZellijTabIndex(pi, zellijSessionName)
    : undefined;

  const scriptCommand = [
    shellEscape(FOCUS_SCRIPT_PATH),
    shellEscape(weztermPaneId),
    shellEscape(zellijSessionName),
    shellEscape(tabIndex ? String(tabIndex) : ""),
    shellEscape(zellijPaneId ?? ""),
  ].join(" ");

  return `bash -lc ${shellEscape(scriptCommand)}`;
}

async function sendMungNotification(
  pi: ExtensionAPI,
  mungCommand: string,
  title: string,
  message: string,
  icon: string,
  onClickCommand?: string,
  tags: string[] = [],
): Promise<void> {
  const normalizedTitle = truncate(normalizeText(title), 80);
  const normalizedMessage = truncate(normalizeText(message), 220);

  const args = [
    "add",
    "--title",
    normalizedTitle,
    "--message",
    normalizedMessage,
    "--icon",
    icon,
    "--sound",
    "default",
  ];

  const uniqueTags = Array.from(new Set([MUNG_TAG, ...tags].map((tag) => normalizeText(tag)).filter(Boolean)));
  for (const tag of uniqueTags) {
    args.push("--tag", tag);
  }

  if (onClickCommand) {
    args.push("--on-click", onClickCommand);
  }

  await tryExec(pi, mungCommand, args);
}

export default function mungNotify(pi: ExtensionAPI) {
  let mungCommand: string | undefined;
  let missingMungNotified = false;
  const pendingAskToolCalls = new Set<string>();

  const ensureMungCommand = async (ctx: ExtensionContext): Promise<string | undefined> => {
    if (mungCommand) return mungCommand;

    mungCommand = await resolveMungCommand(pi);
    if (!mungCommand && ctx.hasUI && !missingMungNotified) {
      missingMungNotified = true;
      ctx.ui.notify("mung not found. Install mungmung to enable desktop alerts.", "warning");
    }

    return mungCommand;
  };

  pi.on("session_start", async (_event, ctx) => {
    await ensureMungCommand(ctx);
  });

  pi.on("agent_start", async (_event, ctx) => {
    const command = await ensureMungCommand(ctx);
    if (!command) return;

    await cleanupActionAlerts(pi, command);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    const command = await ensureMungCommand(ctx);
    if (!command) return;

    await cleanupActionAlerts(pi, command);
  });

  pi.on("tool_execution_start", async (event, ctx) => {
    if (!ASK_TOOL_NAMES.has(event.toolName)) return;
    if (pendingAskToolCalls.has(event.toolCallId)) return;

    pendingAskToolCalls.add(event.toolCallId);

    const command = await ensureMungCommand(ctx);
    if (!command) return;

    const onClickCommand = await buildOnClickCommand(pi);

    await sendMungNotification(
      pi,
      command,
      "Pi needs your confirmation",
      DEFAULT_ACTION_MESSAGE,
      ACTION_ICON,
      onClickCommand,
      [MUNG_ACTION_TAG],
    );
  });

  pi.on("tool_execution_end", async (event, ctx) => {
    if (!ASK_TOOL_NAMES.has(event.toolName)) return;
    pendingAskToolCalls.delete(event.toolCallId);

    const command = await ensureMungCommand(ctx);
    if (!command) return;

    if (toolExecutionWasError(event)) return;

    const cancelled = extractAskCancelledFlag(event);
    if (cancelled === true) return;

    await cleanupActionAlerts(pi, command);
  });

  pi.on("agent_end", async (event, ctx) => {
    const command = await ensureMungCommand(ctx);
    if (!command) return;

    const lastAssistantText = extractLastAssistantText(event.messages);
    const actionRequired = looksLikeActionRequest(lastAssistantText);
    const onClickCommand = await buildOnClickCommand(pi);

    await sendMungNotification(
      pi,
      command,
      actionRequired ? "Pi needs your action" : "Pi task update",
      lastAssistantText ?? (actionRequired ? DEFAULT_ACTION_MESSAGE : DEFAULT_DONE_MESSAGE),
      actionRequired ? ACTION_ICON : UPDATE_ICON,
      onClickCommand,
      actionRequired ? [MUNG_ACTION_TAG] : [],
    );
  });
}
