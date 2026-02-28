import path from "node:path";

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

type TitleState = {
  turn: number;
  consecutiveShift: number;
  renameCount: number;
  lastRenameTurn: number;
  lastAutoName?: string;
};

type PersistedState = Partial<TitleState>;

const WINDOW_SIZE = 6;
const MIN_TURNS_FOR_AUTO_TITLE = 3;
const SHIFT_THRESHOLD = 0.65;
const CONSECUTIVE_REQUIRED = 2;
const COOLDOWN_TURNS = 8;
const MAX_RENAMES_PER_SESSION = 3;
const MAX_TITLE_CHARS = 60;
const MAX_FOCUS_CHARS = 44;

const STATE_ENTRY_TYPE = "dynamic-session-title";

const PIVOT_PATTERNS = [
  /\binstead\b/i,
  /\bnew task\b/i,
  /\bswitch to\b/i,
  /\bdifferent issue\b/i,
  /\bnow let'?s\b/i,
];

const STOPWORDS = new Set([
  "a",
  "an",
  "and",
  "are",
  "as",
  "at",
  "be",
  "by",
  "for",
  "from",
  "how",
  "i",
  "in",
  "is",
  "it",
  "of",
  "on",
  "or",
  "that",
  "the",
  "this",
  "to",
  "we",
  "with",
  "you",
]);

function createInitialState(): TitleState {
  return {
    turn: 0,
    consecutiveShift: 0,
    renameCount: 0,
    lastRenameTurn: -999,
  };
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

function normalizeWhitespace(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function clip(value: string, limit: number): string {
  if (value.length <= limit) return value;
  return `${value.slice(0, Math.max(0, limit - 3)).trim()}...`;
}

function tokenize(value: string): string[] {
  return normalizeWhitespace(value)
    .toLowerCase()
    .replace(/[^a-z0-9\s_-]/g, " ")
    .split(/\s+/)
    .map((token) => token.trim())
    .filter((token) => token.length >= 3 && !STOPWORDS.has(token));
}

function keywordSet(texts: string[]): Set<string> {
  const set = new Set<string>();
  for (const text of texts) {
    for (const token of tokenize(text)) {
      set.add(token);
    }
  }
  return set;
}

function jaccardOverlap(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 && b.size === 0) return 1;
  const intersection = [...a].filter((value) => b.has(value)).length;
  const union = new Set([...a, ...b]).size;
  if (union === 0) return 1;
  return intersection / union;
}

function topKeywords(texts: string[], count: number): string[] {
  const frequencies = new Map<string, number>();
  for (const text of texts) {
    for (const token of tokenize(text)) {
      frequencies.set(token, (frequencies.get(token) ?? 0) + 1);
    }
  }

  return [...frequencies.entries()]
    .sort((a, b) => {
      if (b[1] !== a[1]) return b[1] - a[1];
      return a[0].localeCompare(b[0]);
    })
    .slice(0, count)
    .map(([token]) => token);
}

function hasPivotPhrase(text: string): boolean {
  const normalized = normalizeWhitespace(text);
  return PIVOT_PATTERNS.some((pattern) => pattern.test(normalized));
}

function collectRecentUserTexts(branch: unknown[], count: number): string[] {
  const collected: string[] = [];

  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i] as any;
    if (!entry || entry.type !== "message") continue;

    const message = entry.message;
    if (!message || message.role !== "user") continue;

    const text = normalizeWhitespace(textFromContent(message.content));
    if (!text) continue;

    // Skip slash-command only turns in topic extraction.
    if (text.startsWith("/")) continue;

    collected.push(text);
    if (collected.length >= count) break;
  }

  return collected.reverse();
}

function buildCandidateTitle(project: string, currentWindowTexts: string[]): string {
  const latest = normalizeWhitespace(currentWindowTexts[currentWindowTexts.length - 1] ?? "");
  const focus = latest
    ? clip(latest, MAX_FOCUS_CHARS)
    : topKeywords(currentWindowTexts, 6).join(" ") || "ongoing work";

  return clip(`${project}: ${focus}`, MAX_TITLE_CHARS);
}

function getProjectName(ctx: ExtensionContext): string {
  const project = path.basename(ctx.cwd);
  return project || "session";
}

function loadStateFromSession(ctx: ExtensionContext): TitleState {
  const state = createInitialState();

  const branch = ctx.sessionManager.getBranch() as unknown[];
  for (const rawEntry of branch) {
    const entry = rawEntry as any;
    if (!entry || entry.type !== "custom" || entry.customType !== STATE_ENTRY_TYPE) continue;

    const data = (entry.data ?? {}) as PersistedState;
    if (typeof data.turn === "number") state.turn = data.turn;
    if (typeof data.consecutiveShift === "number") state.consecutiveShift = data.consecutiveShift;
    if (typeof data.renameCount === "number") state.renameCount = data.renameCount;
    if (typeof data.lastRenameTurn === "number") state.lastRenameTurn = data.lastRenameTurn;
    if (typeof data.lastAutoName === "string") state.lastAutoName = data.lastAutoName;
  }

  return state;
}

function getState(ctx: ExtensionContext, stateBySession: Map<string, TitleState>): TitleState {
  const sessionId = ctx.sessionManager.getSessionId();
  const current = stateBySession.get(sessionId);
  if (current) return current;

  const loaded = loadStateFromSession(ctx);
  stateBySession.set(sessionId, loaded);
  return loaded;
}

function persistState(pi: ExtensionAPI, state: TitleState): void {
  pi.appendEntry(STATE_ENTRY_TYPE, {
    turn: state.turn,
    consecutiveShift: state.consecutiveShift,
    renameCount: state.renameCount,
    lastRenameTurn: state.lastRenameTurn,
    lastAutoName: state.lastAutoName,
  });
}

function maybeUpdateTitle(pi: ExtensionAPI, ctx: ExtensionContext, state: TitleState): void {
  if (state.turn < MIN_TURNS_FOR_AUTO_TITLE) return;

  const userTexts = collectRecentUserTexts(ctx.sessionManager.getBranch() as unknown[], WINDOW_SIZE * 2);
  const currentWindow = userTexts.slice(-WINDOW_SIZE);
  if (currentWindow.length === 0) return;

  const previousWindow = userTexts.slice(-(WINDOW_SIZE * 2), -WINDOW_SIZE);
  const latestUserText = currentWindow[currentWindow.length - 1] ?? "";

  const pivotPhraseScore = hasPivotPhrase(latestUserText) ? 1 : 0;
  const keywordOverlap = jaccardOverlap(keywordSet(previousWindow), keywordSet(currentWindow));
  const shiftScore = 0.5 * pivotPhraseScore + 0.5 * (1 - keywordOverlap);

  if (shiftScore >= SHIFT_THRESHOLD) {
    state.consecutiveShift += 1;
  } else {
    state.consecutiveShift = 0;
  }

  const currentName = normalizeWhitespace(pi.getSessionName() ?? "");
  const autoOwned = !currentName || currentName === state.lastAutoName;
  if (!autoOwned) return;

  const candidate = buildCandidateTitle(getProjectName(ctx), currentWindow);
  if (!candidate) return;

  // Initial title set: not counted against rename cap.
  if (!currentName) {
    pi.setSessionName(candidate);
    state.lastAutoName = candidate;
    state.lastRenameTurn = state.turn;
    persistState(pi, state);
    return;
  }

  const stableShift = state.consecutiveShift >= CONSECUTIVE_REQUIRED;
  const cooledDown = state.turn - state.lastRenameTurn >= COOLDOWN_TURNS;
  const underCap = state.renameCount < MAX_RENAMES_PER_SESSION;

  if (!stableShift || !cooledDown || !underCap || candidate === currentName) return;

  pi.setSessionName(candidate);
  state.lastAutoName = candidate;
  state.renameCount += 1;
  state.lastRenameTurn = state.turn;
  state.consecutiveShift = 0;
  persistState(pi, state);
}

export default function dynamicSessionTitle(pi: ExtensionAPI) {
  const stateBySession = new Map<string, TitleState>();

  const hydrateState = (ctx: ExtensionContext) => {
    const sessionId = ctx.sessionManager.getSessionId();
    if (stateBySession.has(sessionId)) return;
    stateBySession.set(sessionId, loadStateFromSession(ctx));
  };

  pi.on("session_start", async (_event, ctx) => {
    hydrateState(ctx);
  });

  pi.on("session_switch", async (_event, ctx) => {
    hydrateState(ctx);
  });

  pi.on("turn_end", async (_event, ctx) => {
    const state = getState(ctx, stateBySession);
    state.turn += 1;
    maybeUpdateTitle(pi, ctx, state);
  });

  pi.registerCommand("session-title-status", {
    description: "Show dynamic session title state",
    handler: async (_args, ctx) => {
      const state = getState(ctx, stateBySession);
      const currentName = normalizeWhitespace(pi.getSessionName() ?? "") || "(none)";
      const autoOwned = currentName === "(none)" || currentName === state.lastAutoName;
      const status = [
        `title=${currentName}`,
        `turn=${state.turn}`,
        `renames=${state.renameCount}/${MAX_RENAMES_PER_SESSION}`,
        `consecutive=${state.consecutiveShift}/${CONSECUTIVE_REQUIRED}`,
        `cooldown=${Math.max(0, COOLDOWN_TURNS - (state.turn - state.lastRenameTurn))}`,
        `autoOwned=${autoOwned}`,
      ].join(" ");

      if (ctx.hasUI) {
        ctx.ui.notify(status, "info");
        return;
      }

      // Command should normally run in interactive mode, but keep a fallback.
      console.log(status);
    },
  });
}
