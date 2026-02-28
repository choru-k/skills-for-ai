import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Key } from "@mariozechner/pi-tui";

const PLAN_STATUS_KEY = "plan-mode";
const DEFAULT_TOOLS = ["read", "bash", "edit", "write"];
const PLAN_TOOL_ALLOWLIST = [
  "read",
  "bash",
  "grep",
  "find",
  "ls",
  "lsp",
  "web_search",
  "web_fetch",
  "ask",
  "AskUserQuestion",
];

const DANGEROUS_BASH_PATTERNS: RegExp[] = [
  /\brm\b/i,
  /\brmdir\b/i,
  /\bmv\b/i,
  /\bcp\b/i,
  /\bmkdir\b/i,
  /\btouch\b/i,
  /\bchmod\b/i,
  /\bchown\b/i,
  /\bgit\s+(add|commit|push|pull|merge|rebase|reset|checkout|cherry-pick|revert|tag|stash)\b/i,
  /\bnpm\s+(install|uninstall|update|ci|publish)\b/i,
  /\byarn\s+(add|remove|install|up|upgrade)\b/i,
  /\bpnpm\s+(add|remove|install|up|update)\b/i,
  /\bpip\s+(install|uninstall)\b/i,
  /\bsudo\b/i,
  /(^|[^<])>(?!>)/,
  />>/,
];

const PLAN_INSTRUCTIONS = `You are in PLAN MODE.

Rules:
- Plan only. Do not implement.
- Do not edit or write files.
- Analyze code and propose a concrete, numbered implementation plan.
- Include target files, risks, and validation steps.
- If requirements are ambiguous, ask clarifying questions first.`;

const PLAN_NEXT_ACTION = {
  proceed: "Proceed to implementation (switch to normal mode)",
  stay: "Stay in plan mode",
  refine: "Refine the plan",
} as const;

function setStatus(ctx: ExtensionContext, enabled: boolean): void {
  if (!ctx.hasUI) return;
  ctx.ui.setStatus(
    PLAN_STATUS_KEY,
    enabled ? ctx.ui.theme.fg("warning", "⏸ plan") : undefined,
  );
}

function isDangerousCommand(command: string): boolean {
  return DANGEROUS_BASH_PATTERNS.some((pattern) => pattern.test(command));
}

function resolveAvailableTools(pi: ExtensionAPI, names: string[]): string[] {
  const available = new Set(pi.getAllTools().map((tool) => tool.name));
  return names.filter((name) => available.has(name));
}

function getLastAssistantText(messages: unknown): string | undefined {
  if (!Array.isArray(messages)) return undefined;

  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const message = messages[index];
    if (!message || typeof message !== "object") continue;

    const typed = message as { role?: unknown; content?: unknown };
    if (typed.role !== "assistant" || !Array.isArray(typed.content)) continue;

    const text = typed.content
      .filter((block): block is { type: "text"; text: string } => {
        if (!block || typeof block !== "object") return false;
        const value = block as { type?: unknown; text?: unknown };
        return value.type === "text" && typeof value.text === "string";
      })
      .map((block) => block.text.trim())
      .filter((line) => line.length > 0)
      .join("\n");

    if (text.length > 0) return text;
  }

  return undefined;
}

function looksLikePlan(text: string | undefined): boolean {
  if (!text) return false;
  if (/\bPlan:\s*\n/i.test(text)) return true;

  const numberedSteps = text.match(/^\s*\d+[.)]\s+\S+/gm);
  return (numberedSteps?.length ?? 0) >= 2;
}

function extractFirstStep(text: string | undefined): string | undefined {
  if (!text) return undefined;
  const match = text.match(/^\s*1[.)]\s+(.+)$/m);
  return match?.[1]?.trim();
}

export default function planMode(pi: ExtensionAPI): void {
  let enabled = false;
  let toolsBeforePlan: string[] | undefined;

  const enable = (ctx: ExtensionContext): void => {
    if (enabled) return;

    enabled = true;
    toolsBeforePlan = pi.getActiveTools();

    const planTools = resolveAvailableTools(pi, PLAN_TOOL_ALLOWLIST);
    if (planTools.length > 0) {
      pi.setActiveTools(planTools);
    }

    setStatus(ctx, true);
    if (ctx.hasUI) {
      ctx.ui.notify("Plan mode enabled (plan-only, no implementation).", "info");
    }
  };

  const disable = (ctx: ExtensionContext): void => {
    if (!enabled) return;

    enabled = false;

    const fallbackTools = toolsBeforePlan && toolsBeforePlan.length > 0
      ? toolsBeforePlan
      : DEFAULT_TOOLS;

    const restoreTools = resolveAvailableTools(pi, fallbackTools);
    if (restoreTools.length > 0) {
      pi.setActiveTools(restoreTools);
    }

    toolsBeforePlan = undefined;
    setStatus(ctx, false);
    if (ctx.hasUI) {
      ctx.ui.notify("Plan mode disabled.", "info");
    }
  };

  pi.registerShortcut(Key.ctrlAlt("f12"), {
    description: "Toggle plan mode",
    handler: async (ctx) => {
      if (enabled) {
        disable(ctx);
      } else {
        enable(ctx);
      }
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    setStatus(ctx, enabled);
  });

  pi.on("session_switch", async (_event, ctx) => {
    setStatus(ctx, enabled);
  });

  pi.on("before_agent_start", async (event) => {
    if (!enabled) return;

    return {
      systemPrompt: `${event.systemPrompt}\n\n${PLAN_INSTRUCTIONS}`,
    };
  });

  pi.on("agent_end", async (event, ctx) => {
    if (!enabled || !ctx.hasUI) return;

    const lastAssistantText = getLastAssistantText(event.messages);
    if (!looksLikePlan(lastAssistantText)) return;

    const choice = await ctx.ui.select("Plan is ready. What next?", [
      PLAN_NEXT_ACTION.proceed,
      PLAN_NEXT_ACTION.stay,
      PLAN_NEXT_ACTION.refine,
    ]);

    if (!choice || choice === PLAN_NEXT_ACTION.stay) return;

    if (choice === PLAN_NEXT_ACTION.proceed) {
      disable(ctx);

      const firstStep = extractFirstStep(lastAssistantText);
      const implementationPrompt = firstStep
        ? `Proceed with implementation based on the plan. Start with: ${firstStep}`
        : "Proceed with implementation based on the plan you just created.";

      pi.sendUserMessage(implementationPrompt);
      return;
    }

    const refinement = await ctx.ui.editor("Refine the plan:", "");
    if (refinement?.trim()) {
      pi.sendUserMessage(refinement.trim());
    }
  });

  pi.on("tool_call", async (event) => {
    if (!enabled) return;

    if (event.toolName === "edit" || event.toolName === "write") {
      return {
        block: true,
        reason: "Plan mode is active. Implementation tools are disabled.",
      };
    }

    if (event.toolName !== "bash") return;

    const command = typeof event.input.command === "string" ? event.input.command : "";
    if (!command || !isDangerousCommand(command)) return;

    return {
      block: true,
      reason: `Plan mode blocked potentially destructive bash command: ${command}`,
    };
  });
}
