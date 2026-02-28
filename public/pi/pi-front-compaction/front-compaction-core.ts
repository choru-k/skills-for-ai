const FRONT_COMPACTION_MARKER = "__PI_FRONT_COMPACTION__";
const DEFAULT_PERCENT = 30;
const MIN_PERCENT = 1;
const MAX_PERCENT = 99;

export type ParsedInstructions = {
  enabled: boolean;
  percent: number;
  focus?: string;
};

export type ParsedCommandArgs = {
  percent: number;
  focus?: string;
  error?: string;
};

export type TurnRange = {
  start: number;
  end: number;
};

export type SessionEntryLike = {
  type: string;
  id?: string;
  message?: {
    role?: string;
    [key: string]: unknown;
  };
  [key: string]: unknown;
};

export function normalizePercent(value: number | undefined): number | undefined {
  if (value === undefined || typeof value !== "number" || !isFinite(value)) {
    return undefined;
  }

  const normalized = Math.floor(value);
  if (normalized < MIN_PERCENT || normalized > MAX_PERCENT) {
    return undefined;
  }

  return normalized;
}

export function parseCommandArgs(args: string): ParsedCommandArgs {
  const trimmed = args.trim();
  if (trimmed.length === 0) {
    return { percent: DEFAULT_PERCENT };
  }

  const [firstToken = "", ...restTokens] = trimmed.split(/\s+/);
  const percentTokenMatch = firstToken.match(/^(-?\d+)%?$/);

  if (!percentTokenMatch) {
    return {
      percent: DEFAULT_PERCENT,
      focus: trimmed,
    };
  }

  const parsedPercent = parseInt(percentTokenMatch[1], 10);
  const normalizedPercent = normalizePercent(parsedPercent);

  if (normalizedPercent === undefined) {
    return {
      percent: DEFAULT_PERCENT,
      error: `Percent must be between ${MIN_PERCENT} and ${MAX_PERCENT}.`,
    };
  }

  const focus = restTokens.join(" ").trim();
  return {
    percent: normalizedPercent,
    focus: focus.length > 0 ? focus : undefined,
  };
}

export function buildCustomInstructions(percent: number, focus?: string): string {
  const payload: { percent: number; focus?: string } = { percent };
  if (focus) {
    payload.focus = focus;
  }

  return `${FRONT_COMPACTION_MARKER}\n${JSON.stringify(payload)}`;
}

export function parseInstructions(customInstructions?: string): ParsedInstructions {
  const raw = customInstructions?.trim();
  if (!raw || raw.indexOf(FRONT_COMPACTION_MARKER) !== 0) {
    return {
      enabled: false,
      percent: DEFAULT_PERCENT,
    };
  }

  const payloadText = raw.slice(FRONT_COMPACTION_MARKER.length).trim();
  if (!payloadText) {
    return {
      enabled: true,
      percent: DEFAULT_PERCENT,
    };
  }

  try {
    const parsed = JSON.parse(payloadText) as { percent?: number; focus?: unknown };
    const percent = normalizePercent(parsed.percent) ?? DEFAULT_PERCENT;

    const focus =
      typeof parsed.focus === "string" && parsed.focus.trim().length > 0 ? parsed.focus.trim() : undefined;

    return {
      enabled: true,
      percent,
      focus,
    };
  } catch {
    return {
      enabled: true,
      percent: DEFAULT_PERCENT,
    };
  }
}

function isUserMessageEntry(entry: SessionEntryLike): boolean {
  return entry.type === "message" && entry.message?.role === "user";
}

function hasAssistantMessage(entries: SessionEntryLike[], start: number, end: number): boolean {
  for (let i = start; i < end; i += 1) {
    const entry = entries[i];
    if (entry?.type === "message" && entry.message?.role === "assistant") {
      return true;
    }
  }
  return false;
}

export function collectCompleteTurns(entries: SessionEntryLike[], startIndex: number, endIndex: number): TurnRange[] {
  const userIndices: number[] = [];

  for (let i = startIndex; i < endIndex; i += 1) {
    if (isUserMessageEntry(entries[i])) {
      userIndices.push(i);
    }
  }

  const turns: TurnRange[] = [];

  for (let i = 0; i < userIndices.length; i += 1) {
    const start = userIndices[i];
    const end = i + 1 < userIndices.length ? userIndices[i + 1] : endIndex;

    if (hasAssistantMessage(entries, start + 1, end)) {
      turns.push({ start, end });
    }
  }

  return turns;
}

export function findLatestCompactionIndex(entries: SessionEntryLike[]): number {
  for (let i = entries.length - 1; i >= 0; i -= 1) {
    if (entries[i]?.type === "compaction") {
      return i;
    }
  }
  return -1;
}

export function collectMessages(entries: SessionEntryLike[], start: number, end: number): unknown[] {
  const messages: unknown[] = [];
  for (let i = start; i < end; i += 1) {
    const entry = entries[i];
    if (entry?.type === "message") {
      messages.push(entry.message);
    }
  }
  return messages;
}

export function minimumTurnsRequired(percent: number): number {
  return Math.ceil(100 / percent);
}
