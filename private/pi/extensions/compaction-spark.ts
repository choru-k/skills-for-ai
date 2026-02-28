import {
  computeFileLists,
  convertToLlm,
  formatFileOperations,
  estimateTokens,
  serializeConversation,
  type ExtensionAPI,
} from "@mariozechner/pi-coding-agent";
import { completeSimple, type Model } from "@mariozechner/pi-ai";

const COMPACTION_PROVIDER = "openai-codex";
const COMPACTION_MODEL_ID = "gpt-5.3-codex-spark";

const CHUNK_TOKEN_FLOOR = 12000;
const CHUNK_TOKEN_CAP = 48000;
const CHUNK_TOKEN_RATIO = 0.45;

const DEFAULT_CONCURRENCY = 3;
const MAX_CONCURRENCY = 6;

const CHUNK_SYSTEM_PROMPT =
  "You are a compaction pre-summarizer. Summarize this chunk of a coding conversation for later merge. Do not continue the conversation.";

const CHUNK_PROMPT = `Summarize this conversation chunk.

Output concise markdown with these sections:

### Goal Signals
- Main user goals in this chunk

### Completed Work
- Concrete completed actions/changes

### In Progress / Blockers
- Ongoing work, blockers, open questions

### Decisions
- Important decisions and rationale

### Critical Technical Facts
- Exact file paths, functions, commands, error messages, constraints

Be precise and factual. Keep exact technical identifiers.`;

const FINAL_SYSTEM_PROMPT =
  "You are a context summarization assistant. Produce one structured compaction summary for another coding model to continue work.";

const FINAL_PROMPT = `You are merging chunk summaries from a long coding conversation into one compaction summary.

Use this EXACT format:

## Goal
[What is the user trying to accomplish? Can be multiple items if the session covers different tasks.]

## Constraints & Preferences
- [Any constraints, preferences, or requirements mentioned by user]
- [Or "(none)" if none were mentioned]

## Progress
### Done
- [x] [Completed tasks/changes]

### In Progress
- [ ] [Current work]

### Blocked
- [Issues preventing progress, if any]

## Key Decisions
- **[Decision]**: [Brief rationale]

## Next Steps
1. [Ordered list of what should happen next]

## Critical Context
- [Any data, examples, or references needed to continue]
- [Or "(none)" if not applicable]

Keep each section concise. Preserve exact file paths, function names, and error messages.`;

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function resolveConcurrency(): number {
  const raw = Number(process.env.PI_COMPACTION_SPARK_CONCURRENCY ?? DEFAULT_CONCURRENCY);
  if (!Number.isFinite(raw)) return DEFAULT_CONCURRENCY;
  return clamp(Math.floor(raw), 1, MAX_CONCURRENCY);
}

function getChunkTokenBudget(model: Model<any>): number {
  const contextWindow = model.contextWindow ?? 128000;
  const byRatio = Math.floor(contextWindow * CHUNK_TOKEN_RATIO);
  return clamp(byRatio, CHUNK_TOKEN_FLOOR, CHUNK_TOKEN_CAP);
}

function chunkMessages(messages: any[], maxChunkTokens: number): any[][] {
  const chunks: any[][] = [];
  let currentChunk: any[] = [];
  let currentTokens = 0;

  for (const message of messages) {
    const messageTokens = Math.max(1, estimateTokens(message));

    if (currentChunk.length > 0 && currentTokens + messageTokens > maxChunkTokens) {
      chunks.push(currentChunk);
      currentChunk = [];
      currentTokens = 0;
    }

    currentChunk.push(message);
    currentTokens += messageTokens;
  }

  if (currentChunk.length > 0) {
    chunks.push(currentChunk);
  }

  return chunks;
}

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  mapper: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  if (items.length === 0) return [];

  const results = new Array<R>(items.length);
  let cursor = 0;

  async function worker() {
    while (true) {
      const index = cursor;
      cursor += 1;
      if (index >= items.length) return;
      results[index] = await mapper(items[index], index);
    }
  }

  const workers = Array.from({ length: Math.min(concurrency, items.length) }, () => worker());
  await Promise.all(workers);
  return results;
}

function collectTextContent(content: Array<{ type: string; text?: string }>): string {
  return content
    .filter((part): part is { type: "text"; text: string } => part.type === "text" && typeof part.text === "string")
    .map(part => part.text)
    .join("\n")
    .trim();
}

async function summarizeChunk(
  model: Model<any>,
  apiKey: string,
  chunk: any[],
  chunkIndex: number,
  chunkCount: number,
  customInstructions: string | undefined,
  signal: AbortSignal,
): Promise<string> {
  const conversation = serializeConversation(convertToLlm(chunk));

  let prompt = `<conversation-chunk index="${chunkIndex + 1}" total="${chunkCount}">\n${conversation}\n</conversation-chunk>\n\n${CHUNK_PROMPT}`;
  if (customInstructions) {
    prompt += `\n\nAdditional focus: ${customInstructions}`;
  }

  const response = await completeSimple(
    model,
    {
      systemPrompt: CHUNK_SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: prompt }],
          timestamp: Date.now(),
        },
      ],
    },
    {
      apiKey,
      signal,
      maxTokens: 3072,
      reasoning: "high",
    },
  );

  if (response.stopReason === "error") {
    throw new Error(response.errorMessage || `Chunk ${chunkIndex + 1} summarization failed`);
  }

  const summary = collectTextContent(response.content as Array<{ type: string; text?: string }>);
  if (!summary) {
    throw new Error(`Chunk ${chunkIndex + 1} summarization returned empty output`);
  }

  return summary;
}

async function mergeChunkSummaries(
  model: Model<any>,
  apiKey: string,
  chunkSummaries: string[],
  previousSummary: string | undefined,
  reserveTokens: number,
  customInstructions: string | undefined,
  signal: AbortSignal,
): Promise<string> {
  const maxTokens = Math.max(2048, Math.floor(reserveTokens * 0.8));

  let prompt = "";

  if (previousSummary) {
    prompt += `<previous-summary>\n${previousSummary}\n</previous-summary>\n\n`;
  }

  prompt += "<chunk-summaries>\n";
  for (let i = 0; i < chunkSummaries.length; i += 1) {
    prompt += `### Chunk ${i + 1}\n${chunkSummaries[i]}\n\n`;
  }
  prompt += `</chunk-summaries>\n\n${FINAL_PROMPT}`;

  if (customInstructions) {
    prompt += `\n\nAdditional focus: ${customInstructions}`;
  }

  const response = await completeSimple(
    model,
    {
      systemPrompt: FINAL_SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: prompt }],
          timestamp: Date.now(),
        },
      ],
    },
    {
      apiKey,
      signal,
      maxTokens,
      reasoning: "high",
    },
  );

  if (response.stopReason === "error") {
    throw new Error(response.errorMessage || "Final compaction merge failed");
  }

  const summary = collectTextContent(response.content as Array<{ type: string; text?: string }>);
  if (!summary) {
    throw new Error("Final compaction merge returned empty output");
  }

  return summary;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_before_compact", async (event, ctx) => {
    const model = ctx.modelRegistry.find(COMPACTION_PROVIDER, COMPACTION_MODEL_ID);
    if (!model) return;

    const apiKey = await ctx.modelRegistry.getApiKey(model);
    if (!apiKey) return;

    const preparation = event.preparation;
    const allMessages = [...preparation.messagesToSummarize, ...preparation.turnPrefixMessages];
    if (allMessages.length === 0) return;

    try {
      const chunkBudget = getChunkTokenBudget(model);
      const chunks = chunkMessages(allMessages, chunkBudget);

      const concurrency = resolveConcurrency();
      const chunkSummaries = await mapWithConcurrency(chunks, concurrency, (chunk, index) =>
        summarizeChunk(model, apiKey, chunk, index, chunks.length, event.customInstructions, event.signal),
      );

      const mergedSummary = await mergeChunkSummaries(
        model,
        apiKey,
        chunkSummaries,
        preparation.previousSummary,
        preparation.settings.reserveTokens,
        event.customInstructions,
        event.signal,
      );

      const { readFiles, modifiedFiles } = computeFileLists(preparation.fileOps);
      const summary = `${mergedSummary}${formatFileOperations(readFiles, modifiedFiles)}`;

      return {
        compaction: {
          summary,
          firstKeptEntryId: preparation.firstKeptEntryId,
          tokensBefore: preparation.tokensBefore,
          details: { readFiles, modifiedFiles },
        },
      };
    } catch {
      if (event.signal.aborted) {
        return { cancel: true };
      }
      return;
    }
  });
}
