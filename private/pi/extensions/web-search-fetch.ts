import * as fs from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES, truncateHead } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

type SearchResult = {
  title: string;
  url: string;
  snippet?: string;
};

type SiteFetchResult = {
  finalUrl: string;
  contentType: string;
  method: string;
  body: string;
  notes?: string[];
};

type CodexAuthRecord = {
  type?: string;
  access?: string;
  refresh?: string;
  expires?: number;
  accountId?: string;
};

type CodexAuthResolved = {
  accessToken: string;
  accountId: string;
};

const CODEX_RESPONSES_URL = "https://chatgpt.com/backend-api/codex/responses";
const CODEX_OAUTH_TOKEN_URL = "https://auth.openai.com/oauth/token";
const CODEX_OAUTH_CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann";
const CODEX_ACCOUNT_CLAIM_PATH = "https://api.openai.com/auth";
const CODEX_DEFAULT_INSTRUCTIONS =
  "Search the web and answer accurately. Cite reliable primary sources and include relevant links in the answer.";

const STACKEXCHANGE_STANDALONE_SITES: Record<string, string> = {
  "stackoverflow.com": "stackoverflow",
  "superuser.com": "superuser",
  "serverfault.com": "serverfault",
  "askubuntu.com": "askubuntu",
  "mathoverflow.net": "mathoverflow",
  "stackapps.com": "stackapps",
};

const MAX_WEB_SEARCH_QUERIES = 8;
const MAX_WEB_SEARCH_CONCURRENCY = 4;
const WEB_SEARCH_INITIAL_CONCURRENCY = 3;

const MAX_FETCH_URLS = 8;
const MAX_FETCH_CONCURRENCY = 4;
const FETCH_INITIAL_CONCURRENCY = 3;

const ADAPTIVE_MIN_CONCURRENCY = 1;
const ADAPTIVE_MAX_RATE_LIMIT_RETRIES = 4;
const ADAPTIVE_BASE_BACKOFF_MS = 1200;
const ADAPTIVE_MAX_BACKOFF_MS = 12000;

function normalizeUrl(input: string): string {
  const trimmed = input.trim();
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return `https://${trimmed}`;
}

function buildTruncationMessage(text: string): string {
  const truncation = truncateHead(text, {
    maxBytes: DEFAULT_MAX_BYTES,
    maxLines: DEFAULT_MAX_LINES,
  });

  if (!truncation.truncated) {
    return truncation.content;
  }

  return `${truncation.content}\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines (${truncation.outputBytes} of ${truncation.totalBytes} bytes). Refine the query or lower the limit for a shorter response.]`;
}

function isRateLimitErrorMessage(message: string): boolean {
  return /(\b429\b|rate\s*limit|too\s*many\s*requests|quota\s*exceeded|resource\s*exhausted|overloaded)/i.test(
    message,
  );
}

async function sleep(ms: number, signal?: AbortSignal): Promise<void> {
  if (ms <= 0) return;
  if (signal?.aborted) throw new Error("Aborted");

  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => {
      signal?.removeEventListener("abort", onAbort);
      resolve();
    }, ms);

    const onAbort = () => {
      clearTimeout(timer);
      signal?.removeEventListener("abort", onAbort);
      reject(new Error("Aborted"));
    };

    signal?.addEventListener("abort", onAbort, { once: true });
  });
}

type AdaptiveBatchOptions = {
  initialConcurrency: number;
  maxConcurrency: number;
  minConcurrency?: number;
  maxRateLimitRetries?: number;
  baseBackoffMs?: number;
  maxBackoffMs?: number;
};

type AdaptiveBatchItemResult<T> =
  | { ok: true; value: T; attempts: number }
  | { ok: false; error: string; attempts: number; rateLimited: boolean };

function isAdaptiveBatchSuccess<T>(result: AdaptiveBatchItemResult<T>): result is { ok: true; value: T; attempts: number } {
  return result.ok;
}

function isAdaptiveBatchFailure<T>(
  result: AdaptiveBatchItemResult<T>,
): result is { ok: false; error: string; attempts: number; rateLimited: boolean } {
  return !result.ok;
}

type AdaptiveBatchRunResult<T> = {
  results: AdaptiveBatchItemResult<T>[];
  stats: {
    initialConcurrency: number;
    finalConcurrency: number;
    slowdownEvents: number;
    retries: number;
  };
};

async function runAdaptiveBatch<TIn, TOut>(
  items: TIn[],
  options: AdaptiveBatchOptions,
  worker: (item: TIn, index: number, attempt: number, signal?: AbortSignal) => Promise<TOut>,
  signal?: AbortSignal,
): Promise<AdaptiveBatchRunResult<TOut>> {
  if (items.length === 0) {
    return {
      results: [],
      stats: { initialConcurrency: 0, finalConcurrency: 0, slowdownEvents: 0, retries: 0 },
    };
  }

  const minConcurrency = Math.max(1, Math.floor(options.minConcurrency ?? ADAPTIVE_MIN_CONCURRENCY));
  const maxConcurrency = Math.max(minConcurrency, Math.floor(options.maxConcurrency));
  const initialConcurrency = Math.max(
    minConcurrency,
    Math.min(maxConcurrency, Math.floor(options.initialConcurrency), items.length),
  );

  const maxRateLimitRetries = Math.max(0, Math.floor(options.maxRateLimitRetries ?? ADAPTIVE_MAX_RATE_LIMIT_RETRIES));
  const baseBackoffMs = Math.max(200, Math.floor(options.baseBackoffMs ?? ADAPTIVE_BASE_BACKOFF_MS));
  const maxBackoffMs = Math.max(baseBackoffMs, Math.floor(options.maxBackoffMs ?? ADAPTIVE_MAX_BACKOFF_MS));

  const attempts = new Array(items.length).fill(0) as number[];
  const pending: number[] = [];
  for (let i = 0; i < items.length; i++) pending.push(i);

  const results = new Array<AdaptiveBatchItemResult<TOut> | undefined>(items.length);
  const inFlight = new Map<number, Promise<{ index: number; ok: true; value: TOut } | { index: number; ok: false; error: unknown }>>();

  let currentConcurrency = initialConcurrency;
  let cooldownUntil = 0;
  let successStreak = 0;
  let slowdownEvents = 0;
  let retries = 0;

  const startTask = (index: number) => {
    const attempt = attempts[index] + 1;
    attempts[index] = attempt;

    const task = (async () => {
      try {
        const value = await worker(items[index], index, attempt, signal);
        return { index, ok: true as const, value };
      } catch (error) {
        return { index, ok: false as const, error };
      }
    })();

    inFlight.set(index, task);
  };

  while (pending.length > 0 || inFlight.size > 0) {
    if (signal?.aborted) throw new Error("Aborted");

    while (pending.length > 0 && inFlight.size < currentConcurrency) {
      if (Date.now() < cooldownUntil) break;
      const index = pending.shift();
      if (index === undefined) break;
      startTask(index);
    }

    if (inFlight.size === 0) {
      const waitMs = Math.max(1, cooldownUntil - Date.now());
      await sleep(waitMs, signal);
      continue;
    }

    const settled = await Promise.race(inFlight.values());
    inFlight.delete(settled.index);

    const attempt = attempts[settled.index] || 1;
    if (settled.ok) {
      results[settled.index] = { ok: true, value: settled.value, attempts: attempt };
      successStreak++;

      if (currentConcurrency < maxConcurrency && successStreak >= currentConcurrency * 2) {
        currentConcurrency++;
        successStreak = 0;
      }

      continue;
    }

    const message = settled.error instanceof Error ? settled.error.message : String(settled.error);
    const rateLimited = isRateLimitErrorMessage(message);

    if (rateLimited && attempt <= maxRateLimitRetries) {
      retries++;
      slowdownEvents++;
      successStreak = 0;
      currentConcurrency = Math.max(minConcurrency, currentConcurrency - 1);

      const backoffMs = Math.min(maxBackoffMs, baseBackoffMs * 2 ** (attempt - 1));
      cooldownUntil = Math.max(cooldownUntil, Date.now() + backoffMs);
      pending.push(settled.index);
      continue;
    }

    results[settled.index] = {
      ok: false,
      error: message,
      attempts: attempt,
      rateLimited,
    };
  }

  return {
    results: results.map((result, index) => {
      if (result) return result;
      return {
        ok: false,
        error: `Unknown batch execution failure at index ${index}`,
        attempts: attempts[index] || 0,
        rateLimited: false,
      };
    }),
    stats: {
      initialConcurrency,
      finalConcurrency: currentConcurrency,
      slowdownEvents,
      retries,
    },
  };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object") return null;
  return value as Record<string, unknown>;
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function asNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function formatCount(value: number | undefined): string | undefined {
  if (value === undefined) return undefined;
  return new Intl.NumberFormat("en-US").format(value);
}

function normalizeHostname(hostname: string): string {
  return hostname.replace(/^www\./i, "").toLowerCase();
}

function decodeBase64Utf8(value: string): string {
  try {
    return Buffer.from(value, "base64").toString("utf-8");
  } catch {
    return "";
  }
}

function getPiAgentDir(): string {
  const configured = process.env.PI_CODING_AGENT_DIR?.trim();
  if (configured) return configured;
  return path.join(os.homedir(), ".pi", "agent");
}

function getPiAuthPath(): string {
  return path.join(getPiAgentDir(), "auth.json");
}

async function readPiAuthFile(): Promise<Record<string, unknown> | null> {
  try {
    const content = await fs.readFile(getPiAuthPath(), "utf-8");
    const parsed = JSON.parse(content) as unknown;
    return asRecord(parsed);
  } catch {
    return null;
  }
}

async function writePiAuthFile(auth: Record<string, unknown>): Promise<void> {
  try {
    await fs.writeFile(getPiAuthPath(), `${JSON.stringify(auth, null, 2)}\n`, "utf-8");
  } catch {
    // best effort only
  }
}

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  const payload = parts[1];
  const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);

  try {
    const decoded = Buffer.from(padded, "base64").toString("utf-8");
    const parsed = JSON.parse(decoded) as unknown;
    return asRecord(parsed);
  } catch {
    return null;
  }
}

function extractCodexAccountId(accessToken: string): string | null {
  const payload = decodeJwtPayload(accessToken);
  const authClaim = payload?.[CODEX_ACCOUNT_CLAIM_PATH];
  const claimRecord = asRecord(authClaim);
  const accountId = claimRecord?.chatgpt_account_id;
  return typeof accountId === "string" && accountId.trim().length > 0 ? accountId.trim() : null;
}

function getCodexAuthRecord(authJson: Record<string, unknown> | null): CodexAuthRecord | null {
  if (!authJson) return null;
  const entry = authJson["openai-codex"];
  const record = asRecord(entry);
  if (!record) return null;
  return record as CodexAuthRecord;
}

function tokenExpired(expiresAt: number | undefined, skewSeconds = 300): boolean {
  if (!expiresAt || !Number.isFinite(expiresAt)) return false;
  return Date.now() >= expiresAt - skewSeconds * 1000;
}

async function refreshCodexToken(refreshToken: string, signal?: AbortSignal): Promise<CodexAuthRecord> {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: CODEX_OAUTH_CLIENT_ID,
  });

  const response = await fetch(CODEX_OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
    signal,
  });

  if (!response.ok) {
    const errorText = (await response.text().catch(() => "")).slice(0, 500);
    throw new Error(`Codex OAuth refresh failed (${response.status})${errorText ? `: ${errorText}` : ""}`);
  }

  const json = (await response.json()) as {
    access_token?: string;
    refresh_token?: string;
    expires_in?: number;
  };

  if (!json.access_token || typeof json.expires_in !== "number") {
    throw new Error("Codex OAuth refresh returned an invalid payload");
  }

  return {
    type: "oauth",
    access: json.access_token,
    refresh: json.refresh_token ?? refreshToken,
    expires: Date.now() + json.expires_in * 1000,
  };
}

async function resolveCodexAuth(signal?: AbortSignal): Promise<CodexAuthResolved | null> {
  const authJson = await readPiAuthFile();
  const record = getCodexAuthRecord(authJson);
  if (!record?.access) return null;

  let current = { ...record };

  if (tokenExpired(current.expires) && current.refresh) {
    try {
      const refreshed = await refreshCodexToken(current.refresh, signal);
      current = {
        ...current,
        ...refreshed,
        accountId: refreshed.accountId ?? current.accountId,
      };

      if (authJson) {
        authJson["openai-codex"] = current;
        await writePiAuthFile(authJson);
      }
    } catch {
      // fall through and try current token, maybe still accepted
    }
  }

  const accountId =
    (typeof current.accountId === "string" && current.accountId.trim().length > 0 ? current.accountId.trim() : null) ??
    extractCodexAccountId(current.access);

  if (!accountId) {
    return null;
  }

  return {
    accessToken: current.access,
    accountId,
  };
}

function extractLinksFromText(text: string, maxLinks: number): SearchResult[] {
  const results: SearchResult[] = [];
  const seen = new Set<string>();

  const markdownLinkRegex = /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g;
  for (const match of text.matchAll(markdownLinkRegex)) {
    const title = match[1]?.trim() ?? "";
    const url = match[2]?.trim() ?? "";
    if (!title || !url || seen.has(url)) continue;
    seen.add(url);
    results.push({ title, url });
    if (results.length >= maxLinks) return results;
  }

  const urlRegex = /https?:\/\/[^\s)\]}>"']+/g;
  for (const match of text.match(urlRegex) ?? []) {
    const url = match.trim();
    if (!url || seen.has(url)) continue;
    seen.add(url);
    results.push({ title: url, url });
    if (results.length >= maxLinks) break;
  }

  return results;
}

async function runCodexWebSearch(
  query: string,
  model: string,
  auth: CodexAuthResolved,
  signal?: AbortSignal,
): Promise<{ answer: string; results: SearchResult[] }> {
  const response = await fetch(CODEX_RESPONSES_URL, {
    method: "POST",
    headers: {
      authorization: `Bearer ${auth.accessToken}`,
      "chatgpt-account-id": auth.accountId,
      "openai-beta": "responses=experimental",
      originator: "pi",
      accept: "text/event-stream",
      "content-type": "application/json",
      "user-agent": "pi-web-search-fetch-extension",
    },
    body: JSON.stringify({
      model,
      stream: true,
      store: false,
      input: [
        {
          type: "message",
          role: "user",
          content: [{ type: "input_text", text: query }],
        },
      ],
      tools: [
        {
          type: "web_search",
          search_context_size: "high",
        },
      ],
      instructions: CODEX_DEFAULT_INSTRUCTIONS,
    }),
    signal,
  });

  if (!response.ok) {
    const errorText = (await response.text().catch(() => "")).slice(0, 500);
    throw new Error(`Codex web search failed (${response.status})${errorText ? `: ${errorText}` : ""}`);
  }

  if (!response.body) {
    throw new Error("Codex web search returned no response body");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  const answerParts: string[] = [];
  const sourceMap = new Map<string, SearchResult>();

  const processData = (data: string) => {
    if (!data || data === "[DONE]") return;

    let event: unknown;
    try {
      event = JSON.parse(data);
    } catch {
      return;
    }

    const eventRecord = asRecord(event);
    const type = typeof eventRecord?.type === "string" ? eventRecord.type : "";

    if (type === "error") {
      const message = typeof eventRecord?.message === "string" ? eventRecord.message : "Codex stream error";
      throw new Error(message);
    }

    if (type === "response.failed") {
      const responseRecord = asRecord(eventRecord?.response);
      const errorRecord = asRecord(responseRecord?.error);
      const message = typeof errorRecord?.message === "string" ? errorRecord.message : "Codex request failed";
      throw new Error(message);
    }

    if (type !== "response.output_item.done") return;

    const item = asRecord(eventRecord?.item);
    if (!item) return;

    const itemType = typeof item.type === "string" ? item.type : "";

    if (itemType === "reasoning") {
      const summary = Array.isArray(item.summary) ? item.summary : [];
      for (const summaryPartRaw of summary) {
        const summaryPart = asRecord(summaryPartRaw);
        if (!summaryPart) continue;
        if (summaryPart.type !== "summary_text") continue;
        const summaryText = typeof summaryPart.text === "string" ? summaryPart.text.trim() : "";
        if (summaryText) answerParts.push(summaryText);
      }
      return;
    }

    if (itemType !== "message") return;

    const content = Array.isArray(item.content) ? item.content : [];
    for (const partRaw of content) {
      const part = asRecord(partRaw);
      if (!part) continue;
      if (part.type !== "output_text") continue;

      const text = typeof part.text === "string" ? part.text.trim() : "";
      if (text) answerParts.push(text);

      const annotations = Array.isArray(part.annotations) ? part.annotations : [];
      for (const annotationRaw of annotations) {
        const annotation = asRecord(annotationRaw);
        if (!annotation || annotation.type !== "url_citation") continue;

        const url = typeof annotation.url === "string" ? annotation.url.trim() : "";
        if (!url || sourceMap.has(url)) continue;

        const title = typeof annotation.title === "string" && annotation.title.trim() ? annotation.title.trim() : url;

        let snippet: string | undefined;
        if (text) {
          const startIndex = typeof annotation.start_index === "number" ? annotation.start_index : 0;
          const endIndex = typeof annotation.end_index === "number" ? annotation.end_index : Math.min(text.length, startIndex + 160);
          const sliceStart = Math.max(0, startIndex - 80);
          const sliceEnd = Math.min(text.length, Math.max(sliceStart + 1, endIndex + 80));
          const extracted = text.slice(sliceStart, sliceEnd).replace(/\s+/g, " ").trim();
          snippet = extracted || undefined;
        }

        sourceMap.set(url, { title, url, snippet });
      }
    }
  };

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });

      const chunks = buffer.split(/\r?\n\r?\n/);
      buffer = chunks.pop() ?? "";

      for (const chunk of chunks) {
        const dataLines = chunk
          .split(/\r?\n/)
          .filter(line => line.startsWith("data:"))
          .map(line => line.slice(5).trim());

        if (dataLines.length === 0) continue;
        processData(dataLines.join("\n"));
      }
    }

    if (buffer.trim().length > 0) {
      const dataLines = buffer
        .split(/\r?\n/)
        .filter(line => line.startsWith("data:"))
        .map(line => line.slice(5).trim());
      if (dataLines.length > 0) {
        processData(dataLines.join("\n"));
      }
    }
  } finally {
    reader.releaseLock();
  }

  const answer = answerParts.join("\n\n").trim();
  const results = [...sourceMap.values()];

  if (results.length === 0 && answer) {
    return {
      answer,
      results: extractLinksFromText(answer, 20),
    };
  }

  return { answer, results };
}

async function searchCodex(
  query: string,
  limit: number,
  signal?: AbortSignal,
): Promise<{ answer: string; results: SearchResult[]; model: string }> {
  const auth = await resolveCodexAuth(signal);
  if (!auth) {
    throw new Error("Codex OAuth credentials not found. Run /login and select openai-codex first.");
  }

  const envModel = process.env.PI_CODEX_WEB_SEARCH_MODEL?.trim();
  const candidateModels = [envModel, "gpt-5.3-codex", "gpt-5-codex-mini", "gpt-5.2-codex"]
    .filter((model): model is string => Boolean(model && model.trim().length > 0));

  const attempted = new Set<string>();
  let lastError: unknown;

  for (const model of candidateModels) {
    if (attempted.has(model)) continue;
    attempted.add(model);

    try {
      const output = await runCodexWebSearch(query, model, auth, signal);
      return {
        answer: output.answer,
        results: output.results.slice(0, limit),
        model,
      };
    } catch (error) {
      lastError = error;
    }
  }

  const message = lastError instanceof Error ? lastError.message : String(lastError ?? "Unknown error");
  throw new Error(`Codex search failed (${[...attempted].join(", ")}): ${message}`);
}

function formatSearchResults(
  query: string,
  provider: string,
  results: SearchResult[],
  options?: { answer?: string; model?: string },
): string {
  const lines: string[] = [];
  lines.push(`Query: ${query}`);
  lines.push(`Provider: ${provider}`);
  if (options?.model) lines.push(`Model: ${options.model}`);
  lines.push(`Results: ${results.length}`);

  if (options?.answer) {
    lines.push("");
    lines.push("Answer:");
    lines.push(options.answer.trim());
  }

  lines.push("");

  results.forEach((result, index) => {
    lines.push(`${index + 1}. ${result.title}`);
    lines.push(`   URL: ${result.url}`);
    if (result.snippet) {
      lines.push(`   Snippet: ${result.snippet}`);
    }
    lines.push("");
  });

  return lines.join("\n").trim();
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutSeconds: number,
  signal?: AbortSignal,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), Math.max(1, timeoutSeconds) * 1000);

  const onAbort = () => controller.abort();
  signal?.addEventListener("abort", onAbort, { once: true });

  try {
    return await fetch(url, {
      ...init,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener("abort", onAbort);
  }
}

function looksLikeHtml(contentType: string, body: string): boolean {
  const type = contentType.toLowerCase();
  if (type.includes("html")) return true;
  const start = body.trimStart().slice(0, 100).toLowerCase();
  return start.startsWith("<!doctype") || start.startsWith("<html") || start.startsWith("<head") || start.startsWith("<body");
}

function basicHtmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function fetchJsonWithTimeout<T>(
  url: string,
  init: RequestInit,
  timeoutSeconds: number,
  signal?: AbortSignal,
): Promise<T | null> {
  const response = await fetchWithTimeout(
    url,
    {
      ...init,
      headers: {
        "user-agent": "pi-web-search-fetch-extension",
        ...(init.headers ?? {}),
      },
    },
    timeoutSeconds,
    signal,
  );

  if (!response.ok) return null;

  try {
    return (await response.json()) as T;
  } catch {
    return null;
  }
}

function getGitHubHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    accept: "application/vnd.github+json",
    "x-github-api-version": "2022-11-28",
  };

  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
  if (token) {
    headers.authorization = `Bearer ${token}`;
  }

  return headers;
}

function maybeAddQuery(url: string, query: string): string {
  return url.includes("?") ? `${url}&${query}` : `${url}?${query}`;
}

async function handleGitHubFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  if (normalizeHostname(parsed.hostname) !== "github.com") return null;

  const parts = parsed.pathname.split("/").filter(Boolean);
  if (parts.length < 2) return null;

  const owner = parts[0];
  const repo = parts[1];
  const section = parts[2];
  const rest = parts.slice(3);

  // File URL: github.com/owner/repo/blob/ref/path/to/file
  if (section === "blob" && rest.length >= 2) {
    const ref = rest[0];
    const filePath = rest.slice(1).join("/");
    const rawUrl = `https://raw.githubusercontent.com/${owner}/${repo}/${ref}/${filePath}`;

    const response = await fetchWithTimeout(rawUrl, { headers: { accept: "text/plain" } }, timeout, signal);
    if (!response.ok) return null;

    return {
      finalUrl: response.url || rawUrl,
      contentType: response.headers.get("content-type") ?? "text/plain",
      method: "github-blob",
      body: await response.text(),
      notes: ["Fetched raw file from GitHub"],
    };
  }

  const ownerEnc = encodeURIComponent(owner);
  const repoEnc = encodeURIComponent(repo);

  // Issue/PR URL
  if ((section === "issues" || section === "pull") && /^\d+$/.test(rest[0] ?? "")) {
    const number = rest[0];
    const issueUrl = `https://api.github.com/repos/${ownerEnc}/${repoEnc}/issues/${number}`;
    const issue = await fetchJsonWithTimeout<Record<string, unknown>>(issueUrl, { headers: getGitHubHeaders() }, timeout, signal);
    if (!issue) return null;

    const title = asString(issue.title) ?? `${owner}/${repo} #${number}`;
    const state = asString(issue.state) ?? "unknown";
    const author = asString(asRecord(issue.user)?.login) ?? "unknown";
    const body = asString(issue.body) ?? "";
    const commentsUrl = asString(issue.comments_url);

    let md = `# ${title}\n\n`;
    md += `**Repo:** ${owner}/${repo}\n`;
    md += `**Type:** ${section === "pull" ? "Pull Request" : "Issue"} #${number}\n`;
    md += `**State:** ${state}\n`;
    md += `**Author:** @${author}\n\n`;
    md += `---\n\n## Body\n\n${body || "(No description)"}\n`;

    if (commentsUrl) {
      const comments = await fetchJsonWithTimeout<unknown[]>(
        maybeAddQuery(commentsUrl, "per_page=5"),
        { headers: getGitHubHeaders() },
        timeout,
        signal,
      );

      const list = asArray(comments);
      if (list.length > 0) {
        md += `\n---\n\n## Top Comments\n`;
        for (const commentRaw of list) {
          const comment = asRecord(commentRaw);
          if (!comment) continue;
          const commentAuthor = asString(asRecord(comment.user)?.login) ?? "unknown";
          const commentBody = asString(comment.body) ?? "";
          md += `\n### @${commentAuthor}\n\n${commentBody || "(No content)"}\n`;
        }
      }
    }

    return {
      finalUrl: parsed.toString(),
      contentType: "text/markdown",
      method: section === "pull" ? "github-pr" : "github-issue",
      body: md,
      notes: ["Fetched via GitHub API"],
    };
  }

  // Repo URL (root)
  if (parts.length === 2) {
    const repoApiUrl = `https://api.github.com/repos/${ownerEnc}/${repoEnc}`;
    const repoData = await fetchJsonWithTimeout<Record<string, unknown>>(repoApiUrl, { headers: getGitHubHeaders() }, timeout, signal);
    if (!repoData) return null;

    const fullName = asString(repoData.full_name) ?? `${owner}/${repo}`;
    const description = asString(repoData.description);
    const stars = formatCount(asNumber(repoData.stargazers_count));
    const forks = formatCount(asNumber(repoData.forks_count));
    const language = asString(repoData.language);
    const homepage = asString(repoData.homepage);

    let md = `# ${fullName}\n\n`;
    if (description) md += `${description}\n\n`;
    if (stars) md += `**Stars:** ${stars}\n`;
    if (forks) md += `**Forks:** ${forks}\n`;
    if (language) md += `**Language:** ${language}\n`;
    if (homepage) md += `**Homepage:** ${homepage}\n`;

    const readmeApiUrl = `https://api.github.com/repos/${ownerEnc}/${repoEnc}/readme`;
    const readmeData = await fetchJsonWithTimeout<Record<string, unknown>>(readmeApiUrl, { headers: getGitHubHeaders() }, timeout, signal);
    const readmeContent = asString(readmeData?.content);
    if (readmeContent) {
      md += `\n---\n\n## README\n\n${decodeBase64Utf8(readmeContent)}`;
    }

    return {
      finalUrl: parsed.toString(),
      contentType: "text/markdown",
      method: "github-repo",
      body: md,
      notes: ["Fetched via GitHub API"],
    };
  }

  return null;
}

function getStackExchangeSite(hostname: string): string | null {
  const host = normalizeHostname(hostname);
  if (STACKEXCHANGE_STANDALONE_SITES[host]) {
    return STACKEXCHANGE_STANDALONE_SITES[host];
  }

  const match = host.match(/^([a-z0-9-]+)\.stackexchange\.com$/i);
  return match?.[1] ?? null;
}

async function handleStackExchangeFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  const site = getStackExchangeSite(parsed.hostname);
  if (!site) return null;

  const questionMatch = parsed.pathname.match(/\/questions\/(\d+)/i);
  if (!questionMatch) return null;

  const questionId = questionMatch[1];
  const questionUrl = `https://api.stackexchange.com/2.3/questions/${questionId}?order=desc&sort=activity&site=${encodeURIComponent(site)}&filter=withbody`;
  const questionData = await fetchJsonWithTimeout<Record<string, unknown>>(questionUrl, {}, timeout, signal);
  const questionItems = asArray(questionData?.items);
  const question = asRecord(questionItems[0]);
  if (!question) return null;

  const title = asString(question.title) ?? `Question ${questionId}`;
  const score = asNumber(question.score);
  const author = asString(asRecord(question.owner)?.display_name) ?? "unknown";
  const questionBody = asString(question.body) ?? "";

  let md = `# ${title}\n\n`;
  md += `**Site:** ${site}\n`;
  if (score !== undefined) md += `**Score:** ${score}\n`;
  md += `**Author:** ${author}\n\n`;
  md += `---\n\n## Question\n\n${basicHtmlToText(questionBody)}\n`;

  const answersUrl = `https://api.stackexchange.com/2.3/questions/${questionId}/answers?order=desc&sort=votes&site=${encodeURIComponent(site)}&filter=withbody`;
  const answersData = await fetchJsonWithTimeout<Record<string, unknown>>(answersUrl, {}, timeout, signal);
  const answers = asArray(answersData?.items).slice(0, 5);

  if (answers.length > 0) {
    md += `\n---\n\n## Top Answers\n`;
    for (const answerRaw of answers) {
      const answer = asRecord(answerRaw);
      if (!answer) continue;
      const answerScore = asNumber(answer.score);
      const answerAuthor = asString(asRecord(answer.owner)?.display_name) ?? "unknown";
      const answerBody = asString(answer.body) ?? "";
      const accepted = Boolean(answer.is_accepted);

      md += `\n### ${accepted ? "[Accepted] " : ""}by ${answerAuthor}${answerScore !== undefined ? ` (score ${answerScore})` : ""}\n\n`;
      md += `${basicHtmlToText(answerBody)}\n`;
    }
  }

  return {
    finalUrl: parsed.toString(),
    contentType: "text/markdown",
    method: "stackexchange",
    body: md,
    notes: ["Fetched via Stack Exchange API"],
  };
}

function parseNpmPackageName(parsed: URL): string | null {
  const host = normalizeHostname(parsed.hostname);

  if (host === "registry.npmjs.org") {
    const pathName = decodeURIComponent(parsed.pathname.replace(/^\//, ""));
    return pathName || null;
  }

  if (host !== "npmjs.com") return null;

  const parts = parsed.pathname.split("/").filter(Boolean);
  if (parts[0] !== "package") return null;

  if ((parts[1] ?? "").startsWith("@")) {
    const scope = parts[1];
    const name = parts[2];
    if (!scope || !name) return null;
    return `${scope}/${name}`;
  }

  return parts[1] ?? null;
}

function extractRepositoryUrl(value: unknown): string | undefined {
  if (typeof value === "string") {
    return value.replace(/^git\+/, "").replace(/\.git$/, "").trim();
  }

  const record = asRecord(value);
  const url = asString(record?.url);
  if (!url) return undefined;
  return url.replace(/^git\+/, "").replace(/\.git$/, "").trim();
}

async function handleNpmFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  const packageName = parseNpmPackageName(parsed);
  if (!packageName) return null;

  const registryPackage = packageName.replace("/", "%2F");
  const registryUrl = `https://registry.npmjs.org/${registryPackage}`;
  const registryData = await fetchJsonWithTimeout<Record<string, unknown>>(registryUrl, {}, timeout, signal);
  if (!registryData) return null;

  const distTags = asRecord(registryData["dist-tags"]);
  const latestVersion = asString(distTags?.latest);

  const versions = asRecord(registryData.versions);
  const latestMeta = latestVersion ? asRecord(versions?.[latestVersion]) : null;

  const description = asString(latestMeta?.description) ?? asString(registryData.description);
  const license = asString(latestMeta?.license);
  const homepage = asString(latestMeta?.homepage);
  const repository = extractRepositoryUrl(latestMeta?.repository);
  const keywords = asArray(latestMeta?.keywords).filter((item): item is string => typeof item === "string");
  const dependencies = asRecord(latestMeta?.dependencies);
  const dependencyCount = dependencies ? Object.keys(dependencies).length : 0;
  const readme = asString(registryData.readme);

  const downloadsUrl = `https://api.npmjs.org/downloads/point/last-week/${encodeURIComponent(packageName)}`;
  const downloadsData = await fetchJsonWithTimeout<Record<string, unknown>>(downloadsUrl, {}, timeout, signal);
  const weeklyDownloads = formatCount(asNumber(downloadsData?.downloads));

  let md = `# npm: ${packageName}\n\n`;
  if (latestVersion) md += `**Latest Version:** ${latestVersion}\n`;
  if (description) md += `**Description:** ${description}\n`;
  if (license) md += `**License:** ${license}\n`;
  if (repository) md += `**Repository:** ${repository}\n`;
  if (homepage) md += `**Homepage:** ${homepage}\n`;
  if (weeklyDownloads) md += `**Downloads (last week):** ${weeklyDownloads}\n`;
  md += `**Dependencies:** ${dependencyCount}\n`;
  if (keywords.length > 0) {
    md += `**Keywords:** ${keywords.slice(0, 20).join(", ")}\n`;
  }

  if (readme) {
    md += `\n---\n\n## README\n\n${readme}`;
  }

  return {
    finalUrl: parsed.toString(),
    contentType: "text/markdown",
    method: "npm",
    body: md,
    notes: ["Fetched via npm registry API"],
  };
}

function parsePyPiPackageName(parsed: URL): string | null {
  if (normalizeHostname(parsed.hostname) !== "pypi.org") return null;
  const parts = parsed.pathname.split("/").filter(Boolean);
  if (parts.length < 2) return null;

  if (parts[0] === "project" || parts[0] === "pypi") {
    return decodeURIComponent(parts[1]);
  }

  return null;
}

async function handlePyPiFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  const packageName = parsePyPiPackageName(parsed);
  if (!packageName) return null;

  const apiUrl = `https://pypi.org/pypi/${encodeURIComponent(packageName)}/json`;
  const data = await fetchJsonWithTimeout<Record<string, unknown>>(apiUrl, {}, timeout, signal);
  if (!data) return null;

  const info = asRecord(data.info);
  if (!info) return null;

  const version = asString(info.version);
  const summary = asString(info.summary);
  const license = asString(info.license);
  const requiresPython = asString(info.requires_python);
  const homePage = asString(info.home_page);
  const projectUrls = asRecord(info.project_urls);
  const repo = asString(projectUrls?.Source) || asString(projectUrls?.Repository);
  const docs = asString(projectUrls?.Documentation) || asString(projectUrls?.Homepage);
  const author = asString(info.author);
  const requiresDist = asArray(info.requires_dist).filter((item): item is string => typeof item === "string");

  const releases = asRecord(data.releases);
  const releaseCount = releases ? Object.keys(releases).length : undefined;

  let md = `# PyPI: ${packageName}\n\n`;
  if (version) md += `**Latest Version:** ${version}\n`;
  if (summary) md += `**Summary:** ${summary}\n`;
  if (author) md += `**Author:** ${author}\n`;
  if (license) md += `**License:** ${license}\n`;
  if (requiresPython) md += `**Requires Python:** ${requiresPython}\n`;
  if (repo) md += `**Repository:** ${repo}\n`;
  if (docs) md += `**Docs:** ${docs}\n`;
  if (homePage) md += `**Homepage:** ${homePage}\n`;
  if (releaseCount !== undefined) md += `**Release count:** ${releaseCount}\n`;
  md += `**Dependencies declared:** ${requiresDist.length}\n`;

  if (requiresDist.length > 0) {
    md += "\n---\n\n## Requires-Dist\n";
    for (const dep of requiresDist.slice(0, 50)) {
      md += `- ${dep}\n`;
    }
    if (requiresDist.length > 50) {
      md += `- ... and ${requiresDist.length - 50} more\n`;
    }
  }

  return {
    finalUrl: parsed.toString(),
    contentType: "text/markdown",
    method: "pypi",
    body: md,
    notes: ["Fetched via PyPI JSON API"],
  };
}

function parseCrateName(parsed: URL): string | null {
  if (normalizeHostname(parsed.hostname) !== "crates.io") return null;
  const parts = parsed.pathname.split("/").filter(Boolean);
  if (parts[0] !== "crates" || !parts[1]) return null;
  return decodeURIComponent(parts[1]);
}

async function handleCratesIoFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  const crateName = parseCrateName(parsed);
  if (!crateName) return null;

  const apiUrl = `https://crates.io/api/v1/crates/${encodeURIComponent(crateName)}`;
  const data = await fetchJsonWithTimeout<Record<string, unknown>>(apiUrl, {}, timeout, signal);
  if (!data) return null;

  const crate = asRecord(data.crate);
  if (!crate) return null;

  const description = asString(crate.description);
  const latestVersion = asString(crate.max_version);
  const downloads = formatCount(asNumber(crate.downloads));
  const recentDownloads = formatCount(asNumber(crate.recent_downloads));
  const repository = asString(crate.repository);
  const documentation = asString(crate.documentation);
  const homepage = asString(crate.homepage);
  const categories = asArray(data.categories)
    .map(item => asString(asRecord(item)?.id))
    .filter((item): item is string => Boolean(item));
  const keywords = asArray(data.keywords)
    .map(item => asString(asRecord(item)?.id))
    .filter((item): item is string => Boolean(item));

  let md = `# crates.io: ${crateName}\n\n`;
  if (latestVersion) md += `**Latest Version:** ${latestVersion}\n`;
  if (description) md += `**Description:** ${description}\n`;
  if (downloads) md += `**Total downloads:** ${downloads}\n`;
  if (recentDownloads) md += `**Recent downloads:** ${recentDownloads}\n`;
  if (repository) md += `**Repository:** ${repository}\n`;
  if (documentation) md += `**Documentation:** ${documentation}\n`;
  if (homepage) md += `**Homepage:** ${homepage}\n`;
  if (keywords.length > 0) md += `**Keywords:** ${keywords.join(", ")}\n`;
  if (categories.length > 0) md += `**Categories:** ${categories.join(", ")}\n`;

  return {
    finalUrl: parsed.toString(),
    contentType: "text/markdown",
    method: "crates-io",
    body: md,
    notes: ["Fetched via crates.io API"],
  };
}

async function handleMdnFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  if (normalizeHostname(parsed.hostname) !== "developer.mozilla.org") return null;

  const parts = parsed.pathname.split("/").filter(Boolean);
  if (parts.length < 3) return null;
  if (parts[1]?.toLowerCase() !== "docs") return null;

  const locale = parts[0].toLowerCase();
  const slug = parts.slice(2).join("/").toLowerCase();
  if (!slug) return null;

  const rawUrl = `https://raw.githubusercontent.com/mdn/content/main/files/${locale}/${slug}/index.md`;
  const response = await fetchWithTimeout(rawUrl, { headers: { accept: "text/plain" } }, timeout, signal);
  if (!response.ok) return null;

  const body = await response.text();
  if (!body.trim()) return null;

  return {
    finalUrl: parsed.toString(),
    contentType: "text/markdown",
    method: "mdn",
    body,
    notes: ["Fetched MDN source markdown from mdn/content"],
  };
}

async function handleReadTheDocsFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  if (!normalizeHostname(parsed.hostname).endsWith(".readthedocs.io")) return null;

  const parts = parsed.pathname.split("/").filter(Boolean);
  if (parts.length < 2) return null;

  const lang = parts[0];
  const version = parts[1];
  const pageParts = parts.slice(2);

  let pagePath = pageParts.join("/");
  if (!pagePath) {
    pagePath = "index";
  }
  pagePath = pagePath.replace(/\.html?$/i, "");

  const base = `https://${parsed.hostname}/${lang}/${version}/_sources/${pagePath}`;
  const candidates = [`${base}.rst.txt`, `${base}.md.txt`];

  for (const candidate of candidates) {
    const response = await fetchWithTimeout(candidate, { headers: { accept: "text/plain" } }, timeout, signal);
    if (!response.ok) continue;
    const body = await response.text();
    if (!body.trim()) continue;

    return {
      finalUrl: parsed.toString(),
      contentType: "text/plain",
      method: "readthedocs",
      body,
      notes: ["Fetched Read the Docs source file"],
    };
  }

  return null;
}

function parseDockerHubImage(parsed: URL): { namespace: string; repo: string } | null {
  const host = normalizeHostname(parsed.hostname);
  if (host !== "hub.docker.com") return null;

  const parts = parsed.pathname.split("/").filter(Boolean);
  if (parts.length < 2) return null;

  // /r/library/nginx
  if (parts[0] === "r" && parts[1] && parts[2]) {
    return { namespace: parts[1], repo: parts[2] };
  }

  // /_/nginx (official images)
  if (parts[0] === "_" && parts[1]) {
    return { namespace: "library", repo: parts[1] };
  }

  // /repository/docker/library/nginx
  if (parts[0] === "repository" && parts[1] === "docker" && parts[2] && parts[3]) {
    return { namespace: parts[2], repo: parts[3] };
  }

  return null;
}

async function handleDockerHubFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  const image = parseDockerHubImage(parsed);
  if (!image) return null;

  const repoApi = `https://hub.docker.com/v2/repositories/${encodeURIComponent(image.namespace)}/${encodeURIComponent(image.repo)}/`;
  const repoData = await fetchJsonWithTimeout<Record<string, unknown>>(repoApi, {}, timeout, signal);
  if (!repoData) return null;

  const imageName = asString(repoData.name) ?? image.repo;
  const namespace = asString(repoData.namespace) ?? image.namespace;
  const description = asString(repoData.description);
  const stars = formatCount(asNumber(repoData.star_count));
  const pulls = formatCount(asNumber(repoData.pull_count));
  const status = asString(repoData.status_description);
  const lastUpdated = asString(repoData.last_updated);

  const tagsApi = `https://hub.docker.com/v2/repositories/${encodeURIComponent(namespace)}/${encodeURIComponent(imageName)}/tags?page_size=10`;
  const tagsData = await fetchJsonWithTimeout<Record<string, unknown>>(tagsApi, {}, timeout, signal);
  const tags = asArray(tagsData?.results)
    .map(item => asString(asRecord(item)?.name))
    .filter((item): item is string => Boolean(item));

  let md = `# Docker Hub: ${namespace}/${imageName}\n\n`;
  if (description) md += `${description}\n\n`;
  if (status) md += `**Status:** ${status}\n`;
  if (stars) md += `**Stars:** ${stars}\n`;
  if (pulls) md += `**Pulls:** ${pulls}\n`;
  if (lastUpdated) md += `**Last Updated:** ${lastUpdated}\n`;

  if (tags.length > 0) {
    md += "\n---\n\n## Tags\n";
    for (const tag of tags) {
      md += `- ${tag}\n`;
    }
  }

  return {
    finalUrl: parsed.toString(),
    contentType: "text/markdown",
    method: "dockerhub",
    body: md,
    notes: ["Fetched via Docker Hub API"],
  };
}

async function handleRfcFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  const host = normalizeHostname(parsed.hostname);
  if (host !== "rfc-editor.org") return null;

  const match = parsed.pathname.match(/rfc(\d{3,5})/i);
  if (!match) return null;

  const rfcNumber = match[1];
  const txtUrl = `https://www.rfc-editor.org/rfc/rfc${rfcNumber}.txt`;
  const response = await fetchWithTimeout(txtUrl, { headers: { accept: "text/plain" } }, timeout, signal);
  if (!response.ok) return null;

  const text = await response.text();
  if (!text.trim()) return null;

  const lines = text.split(/\r?\n/).map(line => line.trim()).filter(Boolean);
  const titleLine = lines.find(line => !/^rfc\s*\d+/i.test(line) && line.length > 8 && line.length < 120);

  let md = `# RFC ${rfcNumber}\n\n`;
  if (titleLine) {
    md += `**Title:** ${titleLine}\n`;
  }
  md += `**Source:** ${txtUrl}\n\n---\n\n${text}`;

  return {
    finalUrl: parsed.toString(),
    contentType: "text/plain",
    method: "rfc",
    body: md,
    notes: ["Fetched canonical RFC text"],
  };
}

function parseOsvId(parsed: URL): string | null {
  const host = normalizeHostname(parsed.hostname);

  if (host === "osv.dev") {
    const parts = parsed.pathname.split("/").filter(Boolean);
    if (parts[0] === "vulnerability" && parts[1]) {
      return decodeURIComponent(parts[1]);
    }
  }

  if (host === "api.osv.dev") {
    const parts = parsed.pathname.split("/").filter(Boolean);
    if (parts[0] === "v1" && parts[1] === "vulns" && parts[2]) {
      return decodeURIComponent(parts[2]);
    }
  }

  return null;
}

async function handleOsvFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  const vulnId = parseOsvId(parsed);
  if (!vulnId) return null;

  const apiUrl = `https://api.osv.dev/v1/vulns/${encodeURIComponent(vulnId)}`;
  const data = await fetchJsonWithTimeout<Record<string, unknown>>(apiUrl, {}, timeout, signal);
  if (!data) return null;

  const id = asString(data.id) ?? vulnId;
  const summary = asString(data.summary);
  const details = asString(data.details);
  const published = asString(data.published);
  const modified = asString(data.modified);
  const aliases = asArray(data.aliases).filter((item): item is string => typeof item === "string");
  const severities = asArray(data.severity)
    .map(item => {
      const severity = asRecord(item);
      if (!severity) return undefined;
      const type = asString(severity.type);
      const score = asString(severity.score);
      if (!type || !score) return undefined;
      return `${type}: ${score}`;
    })
    .filter((item): item is string => Boolean(item));

  const affected = asArray(data.affected)
    .map(item => {
      const affectedItem = asRecord(item);
      const pkg = asRecord(affectedItem?.package);
      const ecosystem = asString(pkg?.ecosystem);
      const name = asString(pkg?.name);
      if (!name) return undefined;
      return ecosystem ? `${ecosystem}/${name}` : name;
    })
    .filter((item): item is string => Boolean(item));

  const refs = asArray(data.references)
    .map(item => {
      const ref = asRecord(item);
      const type = asString(ref?.type) ?? "REFERENCE";
      const refUrl = asString(ref?.url);
      if (!refUrl) return undefined;
      return `${type}: ${refUrl}`;
    })
    .filter((item): item is string => Boolean(item));

  let md = `# OSV: ${id}\n\n`;
  if (summary) md += `${summary}\n\n`;
  if (published) md += `**Published:** ${published}\n`;
  if (modified) md += `**Modified:** ${modified}\n`;
  if (aliases.length > 0) md += `**Aliases:** ${aliases.join(", ")}\n`;
  if (severities.length > 0) md += `**Severity:** ${severities.join(" | ")}\n`;

  if (affected.length > 0) {
    md += "\n---\n\n## Affected Packages\n";
    for (const entry of affected.slice(0, 50)) {
      md += `- ${entry}\n`;
    }
    if (affected.length > 50) md += `- ... and ${affected.length - 50} more\n`;
  }

  if (details) {
    md += `\n---\n\n## Details\n\n${details}\n`;
  }

  if (refs.length > 0) {
    md += "\n---\n\n## References\n";
    for (const ref of refs.slice(0, 30)) {
      md += `- ${ref}\n`;
    }
    if (refs.length > 30) md += `- ... and ${refs.length - 30} more\n`;
  }

  return {
    finalUrl: parsed.toString(),
    contentType: "text/markdown",
    method: "osv",
    body: md,
    notes: ["Fetched via OSV API"],
  };
}

function parseCveId(value: string): string | null {
  const match = value.match(/CVE-\d{4}-\d{4,}/i);
  return match?.[0]?.toUpperCase() ?? null;
}

async function handleNvdFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const parsed = new URL(url);
  const host = normalizeHostname(parsed.hostname);
  if (host !== "nvd.nist.gov") return null;

  const cveId = parseCveId(parsed.pathname) ?? parseCveId(parsed.search);
  if (!cveId) return null;

  const apiUrl = `https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=${encodeURIComponent(cveId)}`;
  const data = await fetchJsonWithTimeout<Record<string, unknown>>(apiUrl, {}, timeout, signal);
  const vulnerabilities = asArray(data?.vulnerabilities);
  const first = asRecord(vulnerabilities[0]);
  const cve = asRecord(first?.cve);
  if (!cve) return null;

  const descriptions = asArray(cve.descriptions);
  const enDescription = descriptions
    .map(item => asRecord(item))
    .find(item => asString(item?.lang)?.toLowerCase() === "en");
  const description = asString(enDescription?.value) ?? asString(asRecord(descriptions[0])?.value);

  const metrics = asRecord(cve.metrics);
  const metricV31 = asRecord(asArray(metrics?.cvssMetricV31)[0]);
  const metricV30 = asRecord(asArray(metrics?.cvssMetricV30)[0]);
  const metricV2 = asRecord(asArray(metrics?.cvssMetricV2)[0]);
  const cvssData = asRecord(metricV31?.cvssData) ?? asRecord(metricV30?.cvssData) ?? asRecord(metricV2?.cvssData);
  const baseScore = asNumber(cvssData?.baseScore);
  const baseSeverity = asString(cvssData?.baseSeverity) ?? asString(metricV2?.baseSeverity);

  const weaknesses = asArray(cve.weaknesses)
    .flatMap(item => asArray(asRecord(item)?.description))
    .map(item => asString(asRecord(item)?.value))
    .filter((item): item is string => Boolean(item));

  const references = asArray(cve.references)
    .map(item => asString(asRecord(item)?.url))
    .filter((item): item is string => Boolean(item));

  let md = `# NVD: ${cveId}\n\n`;
  if (baseScore !== undefined || baseSeverity) {
    md += `**CVSS:** ${baseScore !== undefined ? baseScore : "N/A"}${baseSeverity ? ` (${baseSeverity})` : ""}\n`;
  }
  const published = asString(cve.published);
  const modified = asString(cve.lastModified);
  if (published) md += `**Published:** ${published}\n`;
  if (modified) md += `**Last Modified:** ${modified}\n`;

  if (description) {
    md += `\n---\n\n## Description\n\n${description}\n`;
  }

  if (weaknesses.length > 0) {
    md += "\n---\n\n## Weaknesses\n";
    for (const w of weaknesses.slice(0, 20)) {
      md += `- ${w}\n`;
    }
    if (weaknesses.length > 20) md += `- ... and ${weaknesses.length - 20} more\n`;
  }

  if (references.length > 0) {
    md += "\n---\n\n## References\n";
    for (const ref of references.slice(0, 30)) {
      md += `- ${ref}\n`;
    }
    if (references.length > 30) md += `- ... and ${references.length - 30} more\n`;
  }

  return {
    finalUrl: parsed.toString(),
    contentType: "text/markdown",
    method: "nvd",
    body: md,
    notes: ["Fetched via NVD API"],
  };
}

async function trySiteSpecificFetch(url: string, timeout: number, signal?: AbortSignal): Promise<SiteFetchResult | null> {
  const handlers: Array<(u: string, t: number, s?: AbortSignal) => Promise<SiteFetchResult | null>> = [
    handleGitHubFetch,
    handleStackExchangeFetch,
    handleNpmFetch,
    handlePyPiFetch,
    handleCratesIoFetch,
    handleMdnFetch,
    handleReadTheDocsFetch,
    handleDockerHubFetch,
    handleRfcFetch,
    handleOsvFetch,
    handleNvdFetch,
  ];

  for (const handler of handlers) {
    try {
      const result = await handler(url, timeout, signal);
      if (result) return result;
    } catch {
      // Ignore handler failure and continue with generic fetch.
    }
  }

  return null;
}

type FetchResolvedResult = {
  normalizedUrl: string;
  resolvedUrl: string;
  method: string;
  contentType: string;
  body: string;
  notes: string[];
};

async function fetchReadableUrl(
  requestedUrl: string,
  timeout: number,
  raw: boolean,
  signal?: AbortSignal,
): Promise<FetchResolvedResult> {
  const normalizedUrl = normalizeUrl(requestedUrl);
  let resolvedUrl = normalizedUrl;
  let contentType = "";
  let body = "";
  let method = raw ? "direct" : "jina";
  let notes: string[] = [];

  try {
    if (!raw) {
      const siteSpecific = await trySiteSpecificFetch(normalizedUrl, timeout, signal);
      if (siteSpecific) {
        resolvedUrl = siteSpecific.finalUrl || normalizedUrl;
        contentType = siteSpecific.contentType || "text/markdown";
        body = siteSpecific.body;
        method = siteSpecific.method;
        notes = siteSpecific.notes ?? [];
      } else {
        const jinaUrl = `https://r.jina.ai/${normalizedUrl}`;
        const response = await fetchWithTimeout(
          jinaUrl,
          {
            headers: { accept: "text/plain" },
          },
          timeout,
          signal,
        );

        if (!response.ok) {
          throw new Error(`Jina fetch failed with HTTP ${response.status}`);
        }

        resolvedUrl = response.url || jinaUrl;
        contentType = response.headers.get("content-type") ?? "";
        body = await response.text();
      }
    } else {
      const response = await fetchWithTimeout(normalizedUrl, {}, timeout, signal);
      if (!response.ok) {
        throw new Error(`Fetch failed with HTTP ${response.status}`);
      }
      resolvedUrl = response.url || normalizedUrl;
      contentType = response.headers.get("content-type") ?? "";
      body = await response.text();
      if (looksLikeHtml(contentType, body)) {
        body = basicHtmlToText(body);
      }
    }
  } catch (error) {
    const primaryMessage = error instanceof Error ? error.message : String(error);

    if (!raw) {
      try {
        const fallback = await fetchWithTimeout(normalizedUrl, {}, timeout, signal);
        if (!fallback.ok) {
          throw new Error(`Direct fallback failed with HTTP ${fallback.status}`);
        }

        method = "direct";
        resolvedUrl = fallback.url || normalizedUrl;
        contentType = fallback.headers.get("content-type") ?? "";
        body = await fallback.text();
        if (looksLikeHtml(contentType, body)) {
          body = basicHtmlToText(body);
        }
        notes = [...notes, "Fell back to direct fetch"];
      } catch (fallbackError) {
        const fallbackMessage = fallbackError instanceof Error ? fallbackError.message : String(fallbackError);
        throw new Error(`${primaryMessage}; ${fallbackMessage}`);
      }
    } else {
      throw new Error(primaryMessage);
    }
  }

  return {
    normalizedUrl,
    resolvedUrl,
    method,
    contentType: contentType || "unknown",
    body,
    notes,
  };
}

function formatFetchResult(result: FetchResolvedResult): string {
  const outputLines = [
    "URL: " + result.normalizedUrl,
    "Final URL: " + result.resolvedUrl,
    "Method: " + result.method,
    "Content-Type: " + result.contentType,
  ];
  if (result.notes.length > 0) {
    outputLines.push("Notes: " + result.notes.join("; "));
  }
  outputLines.push("", "---", "", result.body);
  return outputLines.join("\n");
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description:
      "Search the web using Codex only. Batch input via queries[] with adaptive internal slowdown on rate limits.",
    parameters: Type.Object({
      queries: Type.Array(Type.String({ description: "Search query" }), {
        minItems: 1,
        maxItems: MAX_WEB_SEARCH_QUERIES,
        description: `Search queries (1-${MAX_WEB_SEARCH_QUERIES})`,
      }),
      limit: Type.Optional(Type.Number({ minimum: 1, maximum: 10, description: "Maximum results per query (1-10, default: 5)" })),
    }),
    async execute(_toolCallId, params, signal) {
      const queryValues = asArray(params.queries);
      const queries = queryValues.map(value => (typeof value === "string" ? value.trim() : ""));
      const limit = Math.max(1, Math.min(10, Math.floor(asNumber(params.limit) ?? 5)));

      const emptyIndex = queries.findIndex(query => query.length === 0);
      if (emptyIndex !== -1) {
        return {
          content: [{ type: "text", text: `Error: queries[${emptyIndex}] cannot be empty.` }],
          details: { provider: "codex", queries: queries.length, successCount: 0, failureCount: queries.length },
          isError: true,
        };
      }

      const batchRun = await runAdaptiveBatch(
        queries,
        {
          initialConcurrency: Math.min(WEB_SEARCH_INITIAL_CONCURRENCY, queries.length),
          maxConcurrency: MAX_WEB_SEARCH_CONCURRENCY,
        },
        async query => {
          const codex = await searchCodex(query, limit, signal);
          return {
            query,
            answer: codex.answer,
            results: codex.results,
            model: codex.model,
          };
        },
        signal,
      );

      const batchResults = batchRun.results;
      const successCount = batchResults.filter(isAdaptiveBatchSuccess).length;
      const failureCount = batchResults.length - successCount;
      const rateLimitedFailures = batchResults.filter(isAdaptiveBatchFailure).filter(result => result.rateLimited).length;

      const lines: string[] = [
        "Provider: codex",
        `Queries: ${queries.length}`,
        `Succeeded: ${successCount}`,
        `Failed: ${failureCount}`,
        `Adaptive concurrency: ${batchRun.stats.initialConcurrency} -> ${batchRun.stats.finalConcurrency}`,
        `Adaptive retries: ${batchRun.stats.retries}`,
        `Rate-limit slowdowns: ${batchRun.stats.slowdownEvents}`,
        "",
      ];

      batchResults.forEach((result, index) => {
        const query = queries[index] ?? `(query ${index + 1})`;
        lines.push(`### ${index + 1}. ${query}`);
        if (result.attempts > 1) {
          lines.push(`Attempts: ${result.attempts}`);
        }
        lines.push("");

        if (isAdaptiveBatchSuccess(result)) {
          lines.push(
            formatSearchResults(result.value.query, "codex", result.value.results, {
              answer: result.value.answer,
              model: result.value.model,
            }),
          );
        } else {
          lines.push(`Query: ${query}`);
          lines.push("Provider: codex");
          lines.push("Results: 0");
          lines.push("");
          lines.push(`Error: ${result.error}`);
        }

        lines.push("", "---", "");
      });

      const output = lines.join("\n").trim();
      const text = buildTruncationMessage(output);

      return {
        content: [{ type: "text", text }],
        details: {
          provider: "codex",
          queries: queries.length,
          successCount,
          failureCount,
          rateLimitedFailures,
          adaptive: batchRun.stats,
        },
        isError: successCount === 0,
      };
    },
  });

  pi.registerTool({
    name: "web_fetch",
    label: "Web Fetch",
    description:
      "Fetch URLs and return readable text. Batch input via urls[] with adaptive internal slowdown on rate limits. Uses site-specific handlers for GitHub, StackExchange, npm, PyPI, crates.io, MDN, Read the Docs, Docker Hub, RFC, OSV, and NVD when possible; otherwise uses r.jina.ai by default. Set raw=true to force direct fetch.",
    parameters: Type.Object({
      urls: Type.Array(Type.String({ description: "URL to fetch" }), {
        minItems: 1,
        maxItems: MAX_FETCH_URLS,
        description: `URLs to fetch (1-${MAX_FETCH_URLS})`,
      }),
      timeout: Type.Optional(Type.Number({ minimum: 1, maximum: 60, description: "Timeout in seconds (default: 20)" })),
      raw: Type.Optional(Type.Boolean({ description: "Fetch original page directly without readability proxy" })),
    }),
    async execute(_toolCallId, params, signal) {
      const urlValues = asArray(params.urls);
      const urls = urlValues.map(value => (typeof value === "string" ? value.trim() : ""));
      const timeout = Math.max(1, Math.min(60, Math.floor(asNumber(params.timeout) ?? 20)));
      const raw = Boolean(params.raw);

      const emptyIndex = urls.findIndex(url => url.length === 0);
      if (emptyIndex !== -1) {
        return {
          content: [{ type: "text", text: `Error: urls[${emptyIndex}] cannot be empty.` }],
          details: { urls: urls.length, successCount: 0, failureCount: urls.length, raw, timeout },
          isError: true,
        };
      }

      const batchRun = await runAdaptiveBatch(
        urls,
        {
          initialConcurrency: Math.min(FETCH_INITIAL_CONCURRENCY, urls.length),
          maxConcurrency: MAX_FETCH_CONCURRENCY,
        },
        async url => fetchReadableUrl(url, timeout, raw, signal),
        signal,
      );

      const batchResults = batchRun.results;
      const successCount = batchResults.filter(isAdaptiveBatchSuccess).length;
      const failureCount = batchResults.length - successCount;
      const rateLimitedFailures = batchResults.filter(isAdaptiveBatchFailure).filter(result => result.rateLimited).length;

      const lines: string[] = [
        `URLs: ${urls.length}`,
        `Succeeded: ${successCount}`,
        `Failed: ${failureCount}`,
        `Raw mode: ${raw ? "true" : "false"}`,
        `Timeout: ${timeout}s`,
        `Adaptive concurrency: ${batchRun.stats.initialConcurrency} -> ${batchRun.stats.finalConcurrency}`,
        `Adaptive retries: ${batchRun.stats.retries}`,
        `Rate-limit slowdowns: ${batchRun.stats.slowdownEvents}`,
        "",
      ];

      batchResults.forEach((result, index) => {
        const requestedUrl = urls[index] ?? `(url ${index + 1})`;
        lines.push(`### ${index + 1}. ${requestedUrl}`);
        if (result.attempts > 1) {
          lines.push(`Attempts: ${result.attempts}`);
        }
        lines.push("");

        if (isAdaptiveBatchSuccess(result)) {
          lines.push(formatFetchResult(result.value));
        } else {
          lines.push("URL: " + normalizeUrl(requestedUrl));
          lines.push(`Error: ${result.error}`);
        }

        lines.push("", "---", "");
      });

      const output = lines.join("\n").trim();
      const text = buildTruncationMessage(output);

      return {
        content: [{ type: "text", text }],
        details: {
          urls: urls.length,
          successCount,
          failureCount,
          rateLimitedFailures,
          raw,
          timeout,
          adaptive: batchRun.stats,
        },
        isError: successCount === 0,
      };
    },
  });
}
