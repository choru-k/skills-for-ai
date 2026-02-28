import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { complete, type Api, type Model } from "@mariozechner/pi-ai";

type SummaryState = {
  turn: number;
  lastUpdateTurn: number;
  updateCount: number;
  lastSummary?: string;
  lastModel?: string;
  inFlight: boolean;
};

type PersistedSummary = {
  summary?: string;
  turn?: number;
  timestamp?: string;
  model?: string;
};

type DynamicTitleState = {
  turn?: number;
  renameCount?: number;
  lastRenameTurn?: number;
  consecutiveShift?: number;
  lastAutoName?: string;
};

const SUMMARY_ENTRY_TYPE = "resume-summary";
const TITLE_ENTRY_TYPE = "dynamic-session-title";

const MIN_TURNS_FOR_SUMMARY = 4;
const WINDOW_MESSAGES = 10;
const COOLDOWN_TURNS = 16;
const MAX_UPDATES_PER_SESSION = 10;
const MAX_SUMMARY_CHARS = 220;
const MAX_PROMPT_CHARS = 1_200;

const SYSTEM_PROMPT =
  "Update a rolling session summary for resume selection. Return at most two short lines covering: current goal, key decision/progress, immediate next step.";

function clip(value: string, maxChars: number): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  if (normalized.length <= maxChars) return normalized;
  return `${normalized.slice(0, Math.max(0, maxChars - 3)).trim()}...`;
}

function textFromContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  return content
    .filter((c): c is { type?: string; text?: string } => !!c && typeof c === "object")
    .filter((c) => c.type === "text" && typeof c.text === "string")
    .map((c) => c.text)
    .join("\n");
}

function recentConversation(branch: unknown[], count: number): string {
  const lines: string[] = [];

  for (const rawEntry of branch) {
    const entry = rawEntry as any;
    if (!entry || entry.type !== "message") continue;

    const message = entry.message;
    if (!message || (message.role !== "user" && message.role !== "assistant")) continue;

    const text = textFromContent(message.content).trim();
    if (!text) continue;

    const roleLabel = message.role === "user" ? "User" : "Assistant";
    lines.push(`${roleLabel}: ${text}`);
  }

  return lines.slice(-count).join("\n\n");
}

function buildRollingPrompt(state: SummaryState, branch: unknown[]): string {
  const conversation = recentConversation(branch, WINDOW_MESSAGES);
  if (!conversation) return "";

  const parts = [];
  if (state.lastSummary) {
    parts.push("Previous summary:");
    parts.push(clip(state.lastSummary, MAX_SUMMARY_CHARS));
    parts.push("");
  }
  parts.push("Recent conversation:");
  parts.push(conversation);

  return clip(parts.join("\n"), MAX_PROMPT_CHARS);
}

function createInitialState(): SummaryState {
  return {
    turn: 0,
    lastUpdateTurn: -999,
    updateCount: 0,
    inFlight: false,
  };
}

function loadSummaryState(ctx: ExtensionContext): SummaryState {
  const state = createInitialState();
  const branch = ctx.sessionManager.getBranch() as unknown[];

  for (const rawEntry of branch) {
    const entry = rawEntry as any;
    if (!entry || entry.type !== "custom" || entry.customType !== SUMMARY_ENTRY_TYPE) continue;

    const data = (entry.data ?? {}) as PersistedSummary;
    if (typeof data.summary === "string") state.lastSummary = data.summary;
    if (typeof data.model === "string") state.lastModel = data.model;
    if (typeof data.turn === "number") {
      state.turn = Math.max(state.turn, data.turn);
      state.lastUpdateTurn = data.turn;
      state.updateCount += 1;
    }
  }

  return state;
}

function getState(ctx: ExtensionContext, bySession: Map<string, SummaryState>): SummaryState {
  const sessionId = ctx.sessionManager.getSessionId();
  const current = bySession.get(sessionId);
  if (current) return current;

  const loaded = loadSummaryState(ctx);
  bySession.set(sessionId, loaded);
  return loaded;
}

async function selectSummaryModel(
  currentModel: Model<Api> | undefined,
  ctx: ExtensionContext,
): Promise<{ model: Model<Api>; apiKey: string } | null> {
  const preferred = ctx.modelRegistry.find("openai-codex", "gpt-5.3-codex-spark");
  if (preferred) {
    const apiKey = await ctx.modelRegistry.getApiKey(preferred);
    if (apiKey) return { model: preferred, apiKey };
  }

  const fallback = ctx.modelRegistry.find("openai-codex", "gpt-5.1-codex-mini");
  if (fallback) {
    const apiKey = await ctx.modelRegistry.getApiKey(fallback);
    if (apiKey) return { model: fallback, apiKey };
  }

  if (!currentModel) return null;
  const currentApiKey = await ctx.modelRegistry.getApiKey(currentModel);
  if (!currentApiKey) return null;
  return { model: currentModel, apiKey: currentApiKey };
}

function latestDynamicState(ctx: ExtensionContext): DynamicTitleState | undefined {
  const branch = ctx.sessionManager.getBranch() as unknown[];
  let latest: DynamicTitleState | undefined;

  for (const rawEntry of branch) {
    const entry = rawEntry as any;
    if (!entry || entry.type !== "custom" || entry.customType !== TITLE_ENTRY_TYPE) continue;
    latest = (entry.data ?? {}) as DynamicTitleState;
  }

  return latest;
}

async function updateSummary(pi: ExtensionAPI, ctx: ExtensionContext, state: SummaryState): Promise<void> {
  if (state.turn < MIN_TURNS_FOR_SUMMARY) return;
  if (state.turn - state.lastUpdateTurn < COOLDOWN_TURNS) return;
  if (state.updateCount >= MAX_UPDATES_PER_SESSION) return;

  const branch = ctx.sessionManager.getBranch() as unknown[];
  const prompt = buildRollingPrompt(state, branch);
  if (!prompt) return;

  const selected = await selectSummaryModel(ctx.model as Model<Api> | undefined, ctx);
  if (!selected) return;

  const response = await complete(
    selected.model,
    {
      systemPrompt: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: prompt }],
          timestamp: Date.now(),
        },
      ],
    },
    {
      apiKey: selected.apiKey,
      reasoningEffort: "minimal",
    },
  );

  const summary = clip(
    response.content
      .filter((c): c is { type: "text"; text: string } => c.type === "text")
      .map((c) => c.text)
      .join("\n"),
    MAX_SUMMARY_CHARS,
  );

  if (!summary) return;

  state.lastSummary = summary;
  state.lastUpdateTurn = state.turn;
  state.updateCount += 1;
  state.lastModel = `${selected.model.provider}/${selected.model.id}`;

  pi.appendEntry(SUMMARY_ENTRY_TYPE, {
    summary,
    turn: state.turn,
    timestamp: new Date().toISOString(),
    model: state.lastModel,
  });
}

export default function sessionResumeSummary(pi: ExtensionAPI) {
  const stateBySession = new Map<string, SummaryState>();

  const hydrate = (ctx: ExtensionContext) => {
    const sessionId = ctx.sessionManager.getSessionId();
    if (stateBySession.has(sessionId)) return;
    stateBySession.set(sessionId, loadSummaryState(ctx));
  };

  pi.on("session_start", async (_event, ctx) => {
    hydrate(ctx);
  });

  pi.on("session_switch", async (_event, ctx) => {
    hydrate(ctx);
  });

  pi.on("turn_end", async (_event, ctx) => {
    const state = getState(ctx, stateBySession);
    state.turn += 1;

    if (state.inFlight) return;
    state.inFlight = true;

    void updateSummary(pi, ctx, state)
      .catch((error: unknown) => {
        const message = error instanceof Error ? error.message : String(error);
        if (ctx.hasUI) {
          ctx.ui.notify(`session-resume-summary skipped: ${message}`, "warning");
        } else {
          console.warn(`session-resume-summary skipped: ${message}`);
        }
      })
      .finally(() => {
        state.inFlight = false;
      });
  });

  pi.registerCommand("session-summary-status", {
    description: "Show rolling summary metadata state",
    handler: async (_args, ctx) => {
      const state = getState(ctx, stateBySession);
      const summary = state.lastSummary ? clip(state.lastSummary, 120) : "(none)";
      const capReached = state.updateCount >= MAX_UPDATES_PER_SESSION;
      const nextIn = Math.max(0, COOLDOWN_TURNS - (state.turn - state.lastUpdateTurn));

      const text = [
        `updates=${state.updateCount}/${MAX_UPDATES_PER_SESSION}`,
        `turn=${state.turn}`,
        `lastTurn=${state.lastUpdateTurn}`,
        `nextIn=${nextIn}`,
        `capReached=${capReached}`,
        `model=${state.lastModel ?? "(none)"}`,
        `summary=${summary}`,
      ].join(" ");

      if (ctx.hasUI) {
        ctx.ui.notify(text, "info");
      } else {
        console.log(text);
      }
    },
  });

  pi.registerCommand("session-resume-status", {
    description: "Show integrated title + summary resume metadata status",
    handler: async (_args, ctx) => {
      const summaryState = getState(ctx, stateBySession);
      const titleState = latestDynamicState(ctx);
      const currentName = (pi.getSessionName() ?? "").trim() || "(none)";
      const capReached = summaryState.updateCount >= MAX_UPDATES_PER_SESSION;
      const summaryPreview = summaryState.lastSummary ? clip(summaryState.lastSummary, 100) : "(none)";

      const text = [
        `title=${currentName}`,
        `titleRenames=${titleState?.renameCount ?? 0}`,
        `titleTurn=${titleState?.turn ?? 0}`,
        `summaryUpdates=${summaryState.updateCount}/${MAX_UPDATES_PER_SESSION}`,
        `summaryLastTurn=${summaryState.lastUpdateTurn}`,
        `summaryCapReached=${capReached}`,
        `summary=${summaryPreview}`,
      ].join(" ");

      if (ctx.hasUI) {
        ctx.ui.notify(text, "info");
      } else {
        console.log(text);
      }
    },
  });
}
