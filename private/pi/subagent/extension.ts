/**
 * Subagent Tool - Delegate tasks to specialized agents
 *
 * Spawns a separate `pi` process for each subagent invocation,
 * giving it an isolated context window.
 *
 * Supports three modes:
 *   - Single: { agent: "name", task: "..." }
 *   - Parallel: { tasks: [{ agent: "name", task: "..." }, ...] }
 *   - Chain: { chain: [{ agent: "name", task: "... {previous} ..." }, ...] }
 *
 * Uses JSON mode to capture structured output from subagents.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
import { StringEnum } from "@mariozechner/pi-ai";
import { type ExtensionAPI, getMarkdownTheme } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { type AgentConfig, type AgentScope, discoverAgents } from "./agents.js";

const MAX_PARALLEL_TASKS = 16;
const DEFAULT_MAX_CONCURRENCY = 10;
const COLLAPSED_ITEM_COUNT = 10;

function resolveMaxConcurrency(): number {
	const raw = process.env.PI_SUBAGENT_MAX_CONCURRENCY;
	const parsed = raw ? Number.parseInt(raw, 10) : Number.NaN;
	const candidate = Number.isFinite(parsed) ? parsed : DEFAULT_MAX_CONCURRENCY;
	return Math.max(1, Math.min(MAX_PARALLEL_TASKS, candidate));
}

const MAX_CONCURRENCY = resolveMaxConcurrency();

const DEFAULT_SUBAGENT_TRACE_PATH = path.join(os.homedir(), ".pi", "agent", "logs", "subagent-trace.jsonl");
const SUBAGENT_TRACE_ENABLED = process.env.PI_SUBAGENT_TRACE !== "0";
let subagentTraceDirPrepared = false;

function expandHomePath(p: string): string {
	if (p === "~") return os.homedir();
	if (p.startsWith("~/")) return path.join(os.homedir(), p.slice(2));
	return p;
}

const SUBAGENT_TRACE_PATH = expandHomePath((process.env.PI_SUBAGENT_TRACE_PATH || DEFAULT_SUBAGENT_TRACE_PATH).trim());

function clipTraceText(text: string, max = 320): string {
	const singleLine = text.replace(/\s+/g, " ").trim();
	return singleLine.length > max ? `${singleLine.slice(0, max)}...` : singleLine;
}

function makeTraceId(): string {
	return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}-${process.pid}`;
}

function parseTraceDepth(raw: string | undefined): number {
	if (!raw) return 0;
	const parsed = Number.parseInt(raw, 10);
	return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

interface InvocationTraceContext {
	invocationId: string;
	rootInvocationId: string;
	parentInvocationId?: string;
	parentRunId?: string;
	depth: number;
}

function appendSubagentTrace(event: Record<string, unknown>): void {
	if (!SUBAGENT_TRACE_ENABLED) return;
	try {
		if (!subagentTraceDirPrepared) {
			fs.mkdirSync(path.dirname(SUBAGENT_TRACE_PATH), { recursive: true });
			subagentTraceDirPrepared = true;
		}

		const normalizedEvent: Record<string, unknown> = { ...event };
		const invocationId = typeof normalizedEvent.invocationId === "string" ? normalizedEvent.invocationId : undefined;
		if (invocationId) {
			const envParentInvocationId = process.env.PI_SUBAGENT_TRACE_INVOCATION_ID?.trim() || undefined;
			const envParentRunId = process.env.PI_SUBAGENT_TRACE_RUN_ID?.trim() || undefined;
			const envRootInvocationId = process.env.PI_SUBAGENT_TRACE_ROOT_INVOCATION_ID?.trim() || undefined;
			const hasParentInvocation = typeof normalizedEvent.parentInvocationId === "string";
			const hasParentRun = typeof normalizedEvent.parentRunId === "string";
			const hasRoot = typeof normalizedEvent.rootInvocationId === "string";
			const hasDepth = typeof normalizedEvent.depth === "number";

			if (!hasParentInvocation && envParentInvocationId) normalizedEvent.parentInvocationId = envParentInvocationId;
			if (!hasParentRun && envParentRunId) normalizedEvent.parentRunId = envParentRunId;
			if (!hasRoot) {
				normalizedEvent.rootInvocationId =
					envRootInvocationId ||
					(typeof normalizedEvent.parentInvocationId === "string" ? normalizedEvent.parentInvocationId : undefined) ||
					invocationId;
			}
			if (!hasDepth) {
				const inferredHasParent =
					typeof normalizedEvent.parentInvocationId === "string" || Boolean(envParentInvocationId);
				normalizedEvent.depth = inferredHasParent ? parseTraceDepth(process.env.PI_SUBAGENT_TRACE_DEPTH) + 1 : 0;
			}
		}

		const payload = {
			timestamp: new Date().toISOString(),
			pid: process.pid,
			...normalizedEvent,
		};
		fs.appendFileSync(SUBAGENT_TRACE_PATH, `${JSON.stringify(payload)}\n`, { encoding: "utf-8" });
	} catch {
		// ignore trace logging failures
	}
}

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

function formatDurationMs(ms: number | undefined): string {
	const safeMs = Number.isFinite(ms) ? Math.max(0, ms ?? 0) : 0;
	if (safeMs < 1000) return `${Math.round(safeMs)}ms`;
	const totalSeconds = safeMs / 1000;
	if (totalSeconds < 60) return `${totalSeconds.toFixed(1)}s`;
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = Math.floor(totalSeconds % 60);
	if (minutes < 60) return `${minutes}m ${seconds}s`;
	const hours = Math.floor(minutes / 60);
	const remainingMinutes = minutes % 60;
	return `${hours}h ${remainingMinutes}m`;
}

function formatToolCallPlain(toolName: string, args: Record<string, unknown>): string {
	const shortenPath = (p: string) => {
		const home = os.homedir();
		return p.startsWith(home) ? `~${p.slice(home.length)}` : p;
	};
	const clip = (text: string, max = 80) => (text.length > max ? `${text.slice(0, max)}...` : text);

	switch (toolName) {
		case "bash": {
			const command = (args.command as string) || "...";
			return `$ ${clip(command)}`;
		}
		case "read": {
			const rawPath = (args.file_path || args.path || "...") as string;
			return `read ${shortenPath(rawPath)}`;
		}
		case "write": {
			const rawPath = (args.file_path || args.path || "...") as string;
			return `write ${shortenPath(rawPath)}`;
		}
		case "edit": {
			const rawPath = (args.file_path || args.path || "...") as string;
			return `edit ${shortenPath(rawPath)}`;
		}
		case "ls": {
			const rawPath = (args.path || ".") as string;
			return `ls ${shortenPath(rawPath)}`;
		}
		case "find": {
			const pattern = (args.pattern || "*") as string;
			const rawPath = (args.path || ".") as string;
			return `find ${pattern} in ${shortenPath(rawPath)}`;
		}
		case "grep": {
			const pattern = (args.pattern || "") as string;
			const rawPath = (args.path || ".") as string;
			return `grep /${pattern}/ in ${shortenPath(rawPath)}`;
		}
		case "subagent": {
			if (typeof args.agent === "string") return `subagent ${args.agent}`;
			if (Array.isArray(args.tasks)) return `subagent parallel (${args.tasks.length} tasks)`;
			if (Array.isArray(args.chain)) return `subagent chain (${args.chain.length} steps)`;
			return "subagent";
		}
		default: {
			const argsStr = JSON.stringify(args);
			return `${toolName} ${clip(argsStr, 60)}`;
		}
	}
}

function formatUsageStats(
	usage: {
		input: number;
		output: number;
		cacheRead: number;
		cacheWrite: number;
		cost: number;
		contextTokens?: number;
		turns?: number;
	},
	model?: string,
): string {
	const parts: string[] = [];
	if (usage.turns) parts.push(`${usage.turns} turn${usage.turns > 1 ? "s" : ""}`);
	if (usage.input) parts.push(`↑${formatTokens(usage.input)}`);
	if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
	if (usage.cacheRead) parts.push(`R${formatTokens(usage.cacheRead)}`);
	if (usage.cacheWrite) parts.push(`W${formatTokens(usage.cacheWrite)}`);
	if (usage.cost) parts.push(`$${usage.cost.toFixed(4)}`);
	if (usage.contextTokens && usage.contextTokens > 0) {
		parts.push(`ctx:${formatTokens(usage.contextTokens)}`);
	}
	if (model) parts.push(model);
	return parts.join(" ");
}

function formatToolCall(
	toolName: string,
	args: Record<string, unknown>,
	themeFg: (color: any, text: string) => string,
): string {
	const shortenPath = (p: string) => {
		const home = os.homedir();
		return p.startsWith(home) ? `~${p.slice(home.length)}` : p;
	};

	switch (toolName) {
		case "bash": {
			const command = (args.command as string) || "...";
			const preview = command.length > 60 ? `${command.slice(0, 60)}...` : command;
			return themeFg("muted", "$ ") + themeFg("toolOutput", preview);
		}
		case "read": {
			const rawPath = (args.file_path || args.path || "...") as string;
			const filePath = shortenPath(rawPath);
			const offset = args.offset as number | undefined;
			const limit = args.limit as number | undefined;
			let text = themeFg("accent", filePath);
			if (offset !== undefined || limit !== undefined) {
				const startLine = offset ?? 1;
				const endLine = limit !== undefined ? startLine + limit - 1 : "";
				text += themeFg("warning", `:${startLine}${endLine ? `-${endLine}` : ""}`);
			}
			return themeFg("muted", "read ") + text;
		}
		case "write": {
			const rawPath = (args.file_path || args.path || "...") as string;
			const filePath = shortenPath(rawPath);
			const content = (args.content || "") as string;
			const lines = content.split("\n").length;
			let text = themeFg("muted", "write ") + themeFg("accent", filePath);
			if (lines > 1) text += themeFg("dim", ` (${lines} lines)`);
			return text;
		}
		case "edit": {
			const rawPath = (args.file_path || args.path || "...") as string;
			return themeFg("muted", "edit ") + themeFg("accent", shortenPath(rawPath));
		}
		case "ls": {
			const rawPath = (args.path || ".") as string;
			return themeFg("muted", "ls ") + themeFg("accent", shortenPath(rawPath));
		}
		case "find": {
			const pattern = (args.pattern || "*") as string;
			const rawPath = (args.path || ".") as string;
			return themeFg("muted", "find ") + themeFg("accent", pattern) + themeFg("dim", ` in ${shortenPath(rawPath)}`);
		}
		case "grep": {
			const pattern = (args.pattern || "") as string;
			const rawPath = (args.path || ".") as string;
			return (
				themeFg("muted", "grep ") +
				themeFg("accent", `/${pattern}/`) +
				themeFg("dim", ` in ${shortenPath(rawPath)}`)
			);
		}
		default: {
			const argsStr = JSON.stringify(args);
			const preview = argsStr.length > 50 ? `${argsStr.slice(0, 50)}...` : argsStr;
			return themeFg("accent", toolName) + themeFg("dim", ` ${preview}`);
		}
	}
}

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

interface ActiveToolState {
	name: string;
	args: Record<string, unknown>;
	startedAt: string;
	elapsedMs: number;
}

interface SingleResult {
	agent: string;
	agentSource: "user" | "project" | "unknown";
	task: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	step?: number;
	isRunning?: boolean;
	startedAt?: string;
	endedAt?: string;
	elapsedMs?: number;
	statusText?: string;
	activeTool?: ActiveToolState;
}

interface SubagentDetails {
	mode: "single" | "parallel" | "chain";
	agentScope: AgentScope;
	projectAgentsDir: string | null;
	results: SingleResult[];
}

function getFinalOutput(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") return part.text;
			}
		}
	}
	return "";
}

type DisplayItem = { type: "text"; text: string } | { type: "toolCall"; name: string; args: Record<string, any> };

function getDisplayItems(messages: Message[]): DisplayItem[] {
	const items: DisplayItem[] = [];
	for (const msg of messages) {
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") items.push({ type: "text", text: part.text });
				else if (part.type === "toolCall") items.push({ type: "toolCall", name: part.name, args: part.arguments });
			}
		}
	}
	return items;
}

async function mapWithConcurrencyLimit<TIn, TOut>(
	items: TIn[],
	concurrency: number,
	fn: (item: TIn, index: number) => Promise<TOut>,
): Promise<TOut[]> {
	if (items.length === 0) return [];
	const limit = Math.max(1, Math.min(concurrency, items.length));
	const results: TOut[] = new Array(items.length);
	let nextIndex = 0;
	const workers = new Array(limit).fill(null).map(async () => {
		while (true) {
			const current = nextIndex++;
			if (current >= items.length) return;
			results[current] = await fn(items[current], current);
		}
	});
	await Promise.all(workers);
	return results;
}

function writePromptToTempFile(agentName: string, prompt: string): { dir: string; filePath: string } {
	const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-subagent-"));
	const safeName = agentName.replace(/[^\w.-]+/g, "_");
	const filePath = path.join(tmpDir, `prompt-${safeName}.md`);
	fs.writeFileSync(filePath, prompt, { encoding: "utf-8", mode: 0o600 });
	return { dir: tmpDir, filePath };
}

type OnUpdateCallback = (partial: AgentToolResult<SubagentDetails>) => void;

async function runSingleAgent(
	defaultCwd: string,
	agents: AgentConfig[],
	agentName: string,
	task: string,
	cwd: string | undefined,
	step: number | undefined,
	signal: AbortSignal | undefined,
	onUpdate: OnUpdateCallback | undefined,
	makeDetails: (results: SingleResult[]) => SubagentDetails,
	traceContext: InvocationTraceContext,
): Promise<SingleResult> {
	const { invocationId, rootInvocationId, parentInvocationId, parentRunId, depth } = traceContext;
	const agent = agents.find((a) => a.name === agentName);

	if (!agent) {
		const available = agents.map((a) => `"${a.name}"`).join(", ") || "none";
		const nowIso = new Date().toISOString();
		appendSubagentTrace({
			event: "subagent_run_unknown_agent",
			invocationId,
			rootInvocationId,
			parentInvocationId,
			parentRunId,
			depth,
			agent: agentName,
			availableAgents: available,
		});
		return {
			agent: agentName,
			agentSource: "unknown",
			task,
			exitCode: 1,
			messages: [],
			stderr: `Unknown agent: "${agentName}". Available agents: ${available}.`,
			usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
			step,
			isRunning: false,
			startedAt: nowIso,
			endedAt: nowIso,
			elapsedMs: 0,
		};
	}

	const args: string[] = ["--mode", "json", "-p", "--no-session"];
	if (agent.model) args.push("--model", agent.model);
	if (agent.tools && agent.tools.length > 0) args.push("--tools", agent.tools.join(","));

	let tmpPromptDir: string | null = null;
	let tmpPromptPath: string | null = null;
	const startedAtMs = Date.now();
	const startedAtIso = new Date(startedAtMs).toISOString();

	const currentResult: SingleResult = {
		agent: agentName,
		agentSource: agent.source,
		task,
		exitCode: -1,
		messages: [],
		stderr: "",
		usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
		model: agent.model,
		step,
		isRunning: true,
		startedAt: startedAtIso,
		elapsedMs: 0,
		statusText: "Starting subagent...",
	};
	const runId = makeTraceId();
	const runCwd = cwd ?? defaultCwd;
	const traceRunEvent = (event: string, extra: Record<string, unknown> = {}) => {
		appendSubagentTrace({
			event,
			invocationId,
			rootInvocationId,
			parentInvocationId,
			parentRunId,
			depth,
			runId,
			agent: agentName,
			step,
			cwd: runCwd,
			...extra,
		});
	};

	traceRunEvent("subagent_run_start", {
		task: clipTraceText(task),
		model: agent.model,
		tools: agent.tools,
	});

	const updateTiming = () => {
		const now = Date.now();
		currentResult.elapsedMs = now - startedAtMs;
		if (currentResult.activeTool) {
			const toolStartedMs = Date.parse(currentResult.activeTool.startedAt);
			currentResult.activeTool.elapsedMs = Number.isFinite(toolStartedMs) ? now - toolStartedMs : 0;
		}
	};

	const emitUpdate = () => {
		if (onUpdate) {
			updateTiming();
			const finalOutput = getFinalOutput(currentResult.messages);
			let progressText = finalOutput;
			if (!progressText) {
				if (currentResult.statusText) progressText = currentResult.statusText;
				else if (currentResult.activeTool) {
					progressText = `Running ${formatToolCallPlain(currentResult.activeTool.name, currentResult.activeTool.args)}`;
				} else {
					progressText = `(running... ${formatDurationMs(currentResult.elapsedMs)})`;
				}
			}
			onUpdate({
				content: [{ type: "text", text: progressText }],
				details: makeDetails([currentResult]),
			});
		}
	};

	try {
		if (agent.systemPrompt.trim()) {
			const tmp = writePromptToTempFile(agent.name, agent.systemPrompt);
			tmpPromptDir = tmp.dir;
			tmpPromptPath = tmp.filePath;
			args.push("--append-system-prompt", tmpPromptPath);
		}

		args.push(`Task: ${task}`);
		let wasAborted = false;

		const exitCode = await new Promise<number>((resolve) => {
			const childEnv = {
				...process.env,
				PI_SUBAGENT_TRACE: SUBAGENT_TRACE_ENABLED ? "1" : "0",
				PI_SUBAGENT_TRACE_PATH: SUBAGENT_TRACE_PATH,
				PI_SUBAGENT_TRACE_INVOCATION_ID: invocationId,
				PI_SUBAGENT_TRACE_ROOT_INVOCATION_ID: rootInvocationId,
				PI_SUBAGENT_TRACE_RUN_ID: runId,
				PI_SUBAGENT_TRACE_DEPTH: String(depth),
			};
			const proc = spawn("pi", args, {
				cwd: runCwd,
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
				env: childEnv,
			});
			let buffer = "";

			const extractTextFromContent = (content: unknown): string | undefined => {
				if (!Array.isArray(content)) return undefined;
				for (const part of content) {
					if (part && typeof part === "object" && (part as any).type === "text") {
						const text = (part as any).text;
						if (typeof text === "string" && text.trim()) return text;
					}
				}
				return undefined;
			};

			const processLine = (line: string) => {
				if (!line.trim()) return;
				let event: any;
				try {
					event = JSON.parse(line);
				} catch {
					return;
				}
				updateTiming();

				if (event.type === "tool_execution_start") {
					const nowIso = new Date().toISOString();
					const toolName = typeof event.toolName === "string" ? event.toolName : "tool";
					const toolArgs = (event.args && typeof event.args === "object" ? event.args : {}) as Record<string, unknown>;
					currentResult.activeTool = {
						name: toolName,
						args: toolArgs,
						startedAt: nowIso,
						elapsedMs: 0,
					};
					currentResult.statusText = `Running ${formatToolCallPlain(toolName, toolArgs)}`;
					traceRunEvent("subagent_tool_start", {
						toolName,
						toolSummary: formatToolCallPlain(toolName, toolArgs),
						elapsedMs: currentResult.elapsedMs,
					});
					emitUpdate();
					return;
				}

				if (event.type === "tool_execution_update") {
					if (currentResult.activeTool) {
						const partialText = extractTextFromContent(event.partialResult?.content);
						const normalized = partialText?.trim();
						if (normalized && normalized !== "(running...)") {
							currentResult.statusText =
								normalized.length > 240 ? `${normalized.slice(0, 240)}...` : normalized;
						} else {
							currentResult.statusText = `Running ${formatToolCallPlain(
								currentResult.activeTool.name,
								currentResult.activeTool.args,
							)}`;
						}
					}
					emitUpdate();
					return;
				}

				if (event.type === "tool_execution_end") {
					const activeTool = currentResult.activeTool;
					const toolName =
						typeof event.toolName === "string" ? event.toolName : (activeTool?.name ?? "tool");
					const toolArgs = activeTool?.args ?? {};
					const isToolError = event.isError === true || event.result?.isError === true;
					const toolElapsedMs = activeTool?.elapsedMs;
					currentResult.activeTool = undefined;
					currentResult.statusText = `${isToolError ? "Failed" : "Finished"} ${formatToolCallPlain(toolName, toolArgs)}`;
					traceRunEvent("subagent_tool_end", {
						toolName,
						toolSummary: formatToolCallPlain(toolName, toolArgs),
						elapsedMs: toolElapsedMs,
						isError: isToolError,
					});
					emitUpdate();
					return;
				}

				if (event.type === "message_end" && event.message) {
					const msg = event.message as Message;
					currentResult.messages.push(msg);

					if (msg.role === "assistant") {
						currentResult.usage.turns++;
						const usage = msg.usage;
						if (usage) {
							currentResult.usage.input += usage.input || 0;
							currentResult.usage.output += usage.output || 0;
							currentResult.usage.cacheRead += usage.cacheRead || 0;
							currentResult.usage.cacheWrite += usage.cacheWrite || 0;
							currentResult.usage.cost += usage.cost?.total || 0;
							currentResult.usage.contextTokens = usage.totalTokens || 0;
						}
						if (!currentResult.model && msg.model) currentResult.model = msg.model;
						if (msg.stopReason) currentResult.stopReason = msg.stopReason;
						if (msg.errorMessage) currentResult.errorMessage = msg.errorMessage;
						if (msg.stopReason === "toolUse" || msg.stopReason === "error" || msg.stopReason === "aborted") {
							traceRunEvent("subagent_assistant_state", {
								stopReason: msg.stopReason,
								errorMessage: msg.errorMessage ? clipTraceText(msg.errorMessage, 500) : undefined,
								elapsedMs: currentResult.elapsedMs,
							});
						}
					}
					emitUpdate();
					return;
				}

				if (event.type === "tool_result_end" && event.message) {
					currentResult.messages.push(event.message as Message);
					emitUpdate();
				}
			};

			proc.stdout.on("data", (data) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});

			proc.stderr.on("data", (data) => {
				currentResult.stderr += data.toString();
			});

			proc.on("close", (code) => {
				if (buffer.trim()) processLine(buffer);
				resolve(code ?? 0);
			});

			proc.on("error", (err) => {
				traceRunEvent("subagent_process_error", {
					error: clipTraceText(String(err), 500),
					elapsedMs: currentResult.elapsedMs,
				});
				resolve(1);
			});

			if (signal) {
				const killProc = () => {
					wasAborted = true;
					traceRunEvent("subagent_process_abort_requested", { elapsedMs: currentResult.elapsedMs });
					proc.kill("SIGTERM");
					setTimeout(() => {
						if (!proc.killed) proc.kill("SIGKILL");
					}, 5000);
				};
				if (signal.aborted) killProc();
				else signal.addEventListener("abort", killProc, { once: true });
			}
		});

		updateTiming();
		currentResult.exitCode = exitCode;
		currentResult.isRunning = false;
		currentResult.endedAt = new Date().toISOString();
		if (currentResult.activeTool) currentResult.activeTool = undefined;
		traceRunEvent("subagent_run_end", {
			exitCode,
			stopReason: currentResult.stopReason,
			elapsedMs: currentResult.elapsedMs,
			status: wasAborted
				? "aborted"
				: exitCode === 0 && currentResult.stopReason !== "error" && currentResult.stopReason !== "aborted"
					? "success"
					: "error",
			errorMessage: currentResult.errorMessage ? clipTraceText(currentResult.errorMessage, 500) : undefined,
			stderrTail: currentResult.stderr ? clipTraceText(currentResult.stderr.slice(-1200), 800) : undefined,
			usage: currentResult.usage,
		});
		if (wasAborted) throw new Error("Subagent was aborted");
		return currentResult;
	} finally {
		if (tmpPromptPath)
			try {
				fs.unlinkSync(tmpPromptPath);
			} catch {
				/* ignore */
			}
		if (tmpPromptDir)
			try {
				fs.rmdirSync(tmpPromptDir);
			} catch {
				/* ignore */
			}
	}
}

const TaskItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task to delegate to the agent" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
});

const ChainItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task with optional {previous} placeholder for prior output" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
});

const AgentScopeSchema = StringEnum(["user", "project", "both"] as const, {
	description: 'Which agent directories to use. Default: "user". Use "both" to include project-local agents.',
	default: "user",
});

const SubagentParams = Type.Object({
	agent: Type.Optional(Type.String({ description: "Name of the agent to invoke (for single mode)" })),
	task: Type.Optional(Type.String({ description: "Task to delegate (for single mode)" })),
	tasks: Type.Optional(Type.Array(TaskItem, { description: "Array of {agent, task} for parallel execution" })),
	chain: Type.Optional(Type.Array(ChainItem, { description: "Array of {agent, task} for sequential execution" })),
	agentScope: Type.Optional(AgentScopeSchema),
	confirmProjectAgents: Type.Optional(
		Type.Boolean({ description: "Prompt before running project-local agents. Default: true.", default: true }),
	),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process (single mode)" })),
});

export default function (pi: ExtensionAPI) {
	const registerOrchestratorShortcut = (commandName: string) => {
		pi.registerCommand(commandName, {
			description: 'Start the orchestrator subagent workflow (usage: /' + commandName + ' <task>)',
			handler: async (args, ctx) => {
				let task = args.trim();
				if (!task && ctx.hasUI) {
					const input = await ctx.ui.input("Orchestrator task", "Describe what to deliver");
					task = (input ?? "").trim();
				}

				if (!task) {
					if (ctx.hasUI) ctx.ui.notify(`Usage: /${commandName} <task>`, "warning");
					return;
				}

				const userDiscovery = discoverAgents(ctx.cwd, "user");
				const hasUserOrchestrator = userDiscovery.agents.some((a) => a.name === "orchestrator");
				let agentScope: AgentScope = "user";

				if (!hasUserOrchestrator) {
					const bothDiscovery = discoverAgents(ctx.cwd, "both");
					const hasAnyOrchestrator = bothDiscovery.agents.some((a) => a.name === "orchestrator");
					if (!hasAnyOrchestrator) {
						const available = userDiscovery.agents.map((a) => a.name).join(", ") || "none";
						if (ctx.hasUI) {
							ctx.ui.notify(`Agent \"orchestrator\" not found. Available: ${available}`, "error");
						}
						return;
					}
					agentScope = "both";
				}

				pi.sendUserMessage([
					{
						type: "text",
						text: [
							"Run the subagent tool in single mode with:",
							"agent: orchestrator",
							`agentScope: ${agentScope}`,
							`task: ${task}`,
						].join("\n"),
					},
				]);
			},
		});
	};

	registerOrchestratorShortcut("orchestrator");
	registerOrchestratorShortcut("orch");

	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: [
			"Delegate tasks to specialized subagents with isolated context.",
			"Modes: single (agent + task), parallel (tasks array), chain (sequential with {previous} placeholder).",
			"Routing hints: orchestrator for complex coordination; planner for planning; coder for implementation; tester for validation; debugger for root-cause; reviewer for final review; infra-runner for apply-level infra.",
			'Default agent scope is "user" (from ~/.pi/agent/agents).',
			'To enable project-local agents in .pi/agents, set agentScope: "both" (or "project").',
		].join(" "),
		parameters: SubagentParams,

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const agentScope: AgentScope = params.agentScope ?? "user";
			const discovery = discoverAgents(ctx.cwd, agentScope);
			const agents = discovery.agents;
			const confirmProjectAgents = params.confirmProjectAgents ?? true;

			const hasChain = (params.chain?.length ?? 0) > 0;
			const hasTasks = (params.tasks?.length ?? 0) > 0;
			const hasSingle = Boolean(params.agent && params.task);
			const modeCount = Number(hasChain) + Number(hasTasks) + Number(hasSingle);
			const modeLabel: "single" | "parallel" | "chain" | "invalid" = hasChain
				? "chain"
				: hasTasks
					? "parallel"
					: hasSingle
						? "single"
						: "invalid";
			const invocationId = makeTraceId();
			const parentInvocationId = process.env.PI_SUBAGENT_TRACE_INVOCATION_ID?.trim() || undefined;
			const parentRunId = process.env.PI_SUBAGENT_TRACE_RUN_ID?.trim() || undefined;
			const inheritedRootInvocationId = process.env.PI_SUBAGENT_TRACE_ROOT_INVOCATION_ID?.trim() || undefined;
			const parentDepth = parseTraceDepth(process.env.PI_SUBAGENT_TRACE_DEPTH);
			const traceContext: InvocationTraceContext = {
				invocationId,
				rootInvocationId: inheritedRootInvocationId || parentInvocationId || invocationId,
				parentInvocationId,
				parentRunId,
				depth: parentInvocationId ? parentDepth + 1 : 0,
			};
			const traceInvocationEvent = (event: string, extra: Record<string, unknown> = {}) => {
				appendSubagentTrace({ event, ...traceContext, ...extra });
			};

			const requestedAgents = hasChain
				? (params.chain || []).map((step) => step.agent)
				: hasTasks
					? (params.tasks || []).map((task) => task.agent)
					: hasSingle && params.agent
						? [params.agent]
						: [];

			traceInvocationEvent("subagent_invocation_start", {
				mode: modeLabel,
				agentScope,
				cwd: ctx.cwd,
				requestedAgents,
				maxConcurrency: MAX_CONCURRENCY,
				maxParallelTasks: MAX_PARALLEL_TASKS,
				tracePath: SUBAGENT_TRACE_PATH,
			});

			const makeDetails =
				(mode: "single" | "parallel" | "chain") =>
				(results: SingleResult[]): SubagentDetails => ({
					mode,
					agentScope,
					projectAgentsDir: discovery.projectAgentsDir,
					results,
				});

			if (modeCount !== 1) {
				const available = agents.map((a) => `${a.name} (${a.source})`).join(", ") || "none";
				appendSubagentTrace({
					event: "subagent_invocation_end",
					invocationId,
					mode: modeLabel,
					status: "invalid_parameters",
					details: `Provide exactly one mode. Available agents: ${available}`,
				});
				return {
					content: [
						{
							type: "text",
							text: `Invalid parameters. Provide exactly one mode.\nAvailable agents: ${available}`,
						},
					],
					details: makeDetails("single")([]),
				};
			}

			if ((agentScope === "project" || agentScope === "both") && confirmProjectAgents && ctx.hasUI) {
				const requestedAgentNames = new Set<string>();
				if (params.chain) for (const step of params.chain) requestedAgentNames.add(step.agent);
				if (params.tasks) for (const t of params.tasks) requestedAgentNames.add(t.agent);
				if (params.agent) requestedAgentNames.add(params.agent);

				const projectAgentsRequested = Array.from(requestedAgentNames)
					.map((name) => agents.find((a) => a.name === name))
					.filter((a): a is AgentConfig => a?.source === "project");

				if (projectAgentsRequested.length > 0) {
					const names = projectAgentsRequested.map((a) => a.name).join(", ");
					const dir = discovery.projectAgentsDir ?? "(unknown)";
					const ok = await ctx.ui.confirm(
						"Run project-local agents?",
						`Agents: ${names}\nSource: ${dir}\n\nProject agents are repo-controlled. Only continue for trusted repositories.`,
					);
					if (!ok) {
						appendSubagentTrace({
							event: "subagent_invocation_end",
							invocationId,
							mode: modeLabel,
							status: "canceled_project_agents_not_approved",
						});
						return {
							content: [{ type: "text", text: "Canceled: project-local agents not approved." }],
							details: makeDetails(hasChain ? "chain" : hasTasks ? "parallel" : "single")([]),
						};
					}
				}
			}

			if (params.chain && params.chain.length > 0) {
				const results: SingleResult[] = [];
				let previousOutput = "";
				appendSubagentTrace({
					event: "subagent_chain_start",
					invocationId,
					steps: params.chain.length,
				});

				for (let i = 0; i < params.chain.length; i++) {
					const step = params.chain[i];
					const taskWithContext = step.task.replace(/\{previous\}/g, previousOutput);
					appendSubagentTrace({
						event: "subagent_chain_step_start",
						invocationId,
						step: i + 1,
						agent: step.agent,
						cwd: step.cwd ?? ctx.cwd,
						task: clipTraceText(taskWithContext),
					});

					// Create update callback that includes all previous results
					const chainUpdate: OnUpdateCallback | undefined = onUpdate
						? (partial) => {
								// Combine completed results with current streaming result
								const currentResult = partial.details?.results[0];
								if (currentResult) {
									const allResults = [...results, currentResult];
									onUpdate({
										content: partial.content,
										details: makeDetails("chain")(allResults),
									});
								}
							}
						: undefined;

					const result = await runSingleAgent(
						ctx.cwd,
						agents,
						step.agent,
						taskWithContext,
						step.cwd,
						i + 1,
						signal,
						chainUpdate,
						makeDetails("chain"),
						traceContext,
					);
					results.push(result);
					appendSubagentTrace({
						event: "subagent_chain_step_end",
						invocationId,
						step: i + 1,
						agent: step.agent,
						exitCode: result.exitCode,
						stopReason: result.stopReason,
						elapsedMs: result.elapsedMs,
						isError:
							result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted",
					});

					const isError =
						result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
					if (isError) {
						const errorMsg =
							result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
						appendSubagentTrace({
							event: "subagent_invocation_end",
							invocationId,
							mode: "chain",
							status: "error",
							error: clipTraceText(errorMsg, 500),
						});
						return {
							content: [{ type: "text", text: `Chain stopped at step ${i + 1} (${step.agent}): ${errorMsg}` }],
							details: makeDetails("chain")(results),
							isError: true,
						};
					}
					previousOutput = getFinalOutput(result.messages);
				}
				appendSubagentTrace({
					event: "subagent_invocation_end",
					invocationId,
					mode: "chain",
					status: "success",
					steps: results.length,
					elapsedMs: results.reduce((sum, r) => sum + (r.elapsedMs ?? 0), 0),
				});
				return {
					content: [{ type: "text", text: getFinalOutput(results[results.length - 1].messages) || "(no output)" }],
					details: makeDetails("chain")(results),
				};
			}

			if (params.tasks && params.tasks.length > 0) {
				if (params.tasks.length > MAX_PARALLEL_TASKS) {
					appendSubagentTrace({
						event: "subagent_invocation_end",
						invocationId,
						mode: "parallel",
						status: "too_many_parallel_tasks",
						taskCount: params.tasks.length,
						maxParallelTasks: MAX_PARALLEL_TASKS,
					});
					return {
						content: [
							{
								type: "text",
								text: `Too many parallel tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_TASKS}.`,
							},
						],
						details: makeDetails("parallel")([]),
					};
				}

				appendSubagentTrace({
					event: "subagent_parallel_start",
					invocationId,
					taskCount: params.tasks.length,
					maxConcurrency: MAX_CONCURRENCY,
				});

				// Track all results for streaming updates
				const allResults: SingleResult[] = new Array(params.tasks.length);

				// Initialize placeholder results
				for (let i = 0; i < params.tasks.length; i++) {
					allResults[i] = {
						agent: params.tasks[i].agent,
						agentSource: "unknown",
						task: params.tasks[i].task,
						exitCode: -1, // -1 = still running
						messages: [],
						stderr: "",
						usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
						isRunning: true,
						startedAt: new Date().toISOString(),
						elapsedMs: 0,
					};
				}

				const emitParallelUpdate = () => {
					if (onUpdate) {
						const running = allResults.filter((r) => r.isRunning || r.exitCode === -1).length;
						const done = allResults.length - running;
						onUpdate({
							content: [
								{
									type: "text",
									text: `Parallel: ${done}/${allResults.length} done, ${running} running (max ${MAX_CONCURRENCY})...`,
								},
							],
							details: makeDetails("parallel")([...allResults]),
						});
					}
				};

				const results = await mapWithConcurrencyLimit(params.tasks, MAX_CONCURRENCY, async (t, index) => {
					appendSubagentTrace({
						event: "subagent_parallel_task_start",
						invocationId,
						index,
						agent: t.agent,
						cwd: t.cwd ?? ctx.cwd,
						task: clipTraceText(t.task),
					});
					const result = await runSingleAgent(
						ctx.cwd,
						agents,
						t.agent,
						t.task,
						t.cwd,
						undefined,
						signal,
						// Per-task update callback
						(partial) => {
							if (partial.details?.results[0]) {
								allResults[index] = partial.details.results[0];
								emitParallelUpdate();
							}
						},
						makeDetails("parallel"),
						traceContext,
					);
					allResults[index] = result;
					emitParallelUpdate();
					appendSubagentTrace({
						event: "subagent_parallel_task_end",
						invocationId,
						index,
						agent: t.agent,
						exitCode: result.exitCode,
						stopReason: result.stopReason,
						elapsedMs: result.elapsedMs,
						isError:
							result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted",
					});
					return result;
				});

				const successCount = results.filter((r) => r.exitCode === 0).length;
				const summaries = results.map((r) => {
					const output = getFinalOutput(r.messages);
					const preview = output.slice(0, 100) + (output.length > 100 ? "..." : "");
					const elapsed = formatDurationMs(r.elapsedMs);
					return `[${r.agent}] ${r.exitCode === 0 ? "completed" : "failed"} (${elapsed}): ${preview || "(no output)"}`;
				});
				appendSubagentTrace({
					event: "subagent_invocation_end",
					invocationId,
					mode: "parallel",
					status: successCount === results.length ? "success" : "partial_failure",
					taskCount: results.length,
					successCount,
					elapsedMs: results.reduce((sum, r) => sum + (r.elapsedMs ?? 0), 0),
				});
				return {
					content: [
						{
							type: "text",
							text: `Parallel: ${successCount}/${results.length} succeeded (max concurrency ${MAX_CONCURRENCY})\n\n${summaries.join("\n\n")}`,
						},
					],
					details: makeDetails("parallel")(results),
				};
			}

			if (params.agent && params.task) {
				appendSubagentTrace({
					event: "subagent_single_start",
					invocationId,
					agent: params.agent,
					cwd: params.cwd ?? ctx.cwd,
					task: clipTraceText(params.task),
				});
				const result = await runSingleAgent(
					ctx.cwd,
					agents,
					params.agent,
					params.task,
					params.cwd,
					undefined,
					signal,
					onUpdate,
					makeDetails("single"),
					traceContext,
				);
				const isError = result.exitCode !== 0 || result.stopReason === "error" || result.stopReason === "aborted";
				if (isError) {
					const errorMsg =
						result.errorMessage || result.stderr || getFinalOutput(result.messages) || "(no output)";
					appendSubagentTrace({
						event: "subagent_invocation_end",
						invocationId,
						mode: "single",
						status: "error",
						agent: params.agent,
						elapsedMs: result.elapsedMs,
						error: clipTraceText(errorMsg, 500),
					});
					return {
						content: [{ type: "text", text: `Agent ${result.stopReason || "failed"}: ${errorMsg}` }],
						details: makeDetails("single")([result]),
						isError: true,
					};
				}
				appendSubagentTrace({
					event: "subagent_invocation_end",
					invocationId,
					mode: "single",
					status: "success",
					agent: params.agent,
					elapsedMs: result.elapsedMs,
				});
				return {
					content: [{ type: "text", text: getFinalOutput(result.messages) || "(no output)" }],
					details: makeDetails("single")([result]),
				};
			}

			const available = agents.map((a) => `${a.name} (${a.source})`).join(", ") || "none";
			appendSubagentTrace({
				event: "subagent_invocation_end",
				invocationId,
				mode: modeLabel,
				status: "invalid_parameters",
				details: `Invalid parameters. Available agents: ${available}`,
			});
			return {
				content: [{ type: "text", text: `Invalid parameters. Available agents: ${available}` }],
				details: makeDetails("single")([]),
			};
		},

		renderCall(args, theme) {
			const scope: AgentScope = args.agentScope ?? "user";
			if (args.chain && args.chain.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", `chain (${args.chain.length} steps)`) +
					theme.fg("muted", ` [${scope}]`);
				for (let i = 0; i < Math.min(args.chain.length, 3); i++) {
					const step = args.chain[i];
					// Clean up {previous} placeholder for display
					const cleanTask = step.task.replace(/\{previous\}/g, "").trim();
					const preview = cleanTask.length > 40 ? `${cleanTask.slice(0, 40)}...` : cleanTask;
					text +=
						"\n  " +
						theme.fg("muted", `${i + 1}.`) +
						" " +
						theme.fg("accent", step.agent) +
						theme.fg("dim", ` ${preview}`);
				}
				if (args.chain.length > 3) text += `\n  ${theme.fg("muted", `... +${args.chain.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}
			if (args.tasks && args.tasks.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", `parallel (${args.tasks.length} tasks, max ${MAX_CONCURRENCY})`) +
					theme.fg("muted", ` [${scope}]`);
				for (const t of args.tasks.slice(0, 3)) {
					const preview = t.task.length > 40 ? `${t.task.slice(0, 40)}...` : t.task;
					text += `\n  ${theme.fg("accent", t.agent)}${theme.fg("dim", ` ${preview}`)}`;
				}
				if (args.tasks.length > 3) text += `\n  ${theme.fg("muted", `... +${args.tasks.length - 3} more`)}`;
				return new Text(text, 0, 0);
			}
			const agentName = args.agent || "...";
			const preview = args.task ? (args.task.length > 60 ? `${args.task.slice(0, 60)}...` : args.task) : "...";
			let text =
				theme.fg("toolTitle", theme.bold("subagent ")) +
				theme.fg("accent", agentName) +
				theme.fg("muted", ` [${scope}]`);
			text += `\n  ${theme.fg("dim", preview)}`;
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as SubagentDetails | undefined;
			if (!details || details.results.length === 0) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}

			const mdTheme = getMarkdownTheme();

			const renderDisplayItems = (items: DisplayItem[], limit?: number) => {
				const toShow = limit ? items.slice(-limit) : items;
				const skipped = limit && items.length > limit ? items.length - limit : 0;
				let text = "";
				if (skipped > 0) text += theme.fg("muted", `... ${skipped} earlier items\n`);
				for (const item of toShow) {
					if (item.type === "text") {
						const preview = expanded ? item.text : item.text.split("\n").slice(0, 3).join("\n");
						text += `${theme.fg("toolOutput", preview)}\n`;
					} else {
						text += `${theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme))}\n`;
					}
				}
				return text.trimEnd();
			};

			const isAgentRunning = (r: SingleResult) => r.isRunning === true || r.exitCode === -1;
			const isAgentError = (r: SingleResult) =>
				!isAgentRunning(r) && (r.exitCode !== 0 || r.stopReason === "error" || r.stopReason === "aborted");
			const makeAgentTimingText = (r: SingleResult) => formatDurationMs(r.elapsedMs);
			const makeAgentStatusText = (r: SingleResult) => {
				const elapsed = makeAgentTimingText(r);
				if (isAgentRunning(r)) {
					if (r.activeTool)
						return `running ${formatToolCallPlain(r.activeTool.name, r.activeTool.args)} · ${formatDurationMs(r.activeTool.elapsedMs)} (agent ${elapsed})`;
					if (r.statusText) return `${r.statusText} · ${elapsed}`;
					return `running · ${elapsed}`;
				}
				if (isAgentError(r)) return `failed · ${elapsed}`;
				return `done · ${elapsed}`;
			};

			if (details.mode === "single" && details.results.length === 1) {
				const r = details.results[0];
				const isRunning = isAgentRunning(r);
				const isError = isAgentError(r);
				const icon = isRunning
					? theme.fg("warning", "⏳")
					: isError
						? theme.fg("error", "✗")
						: theme.fg("success", "✓");
				const displayItems = getDisplayItems(r.messages);
				const finalOutput = getFinalOutput(r.messages);
				const statusText = makeAgentStatusText(r);

				if (expanded) {
					const container = new Container();
					let header = `${icon} ${theme.fg("toolTitle", theme.bold(r.agent))}${theme.fg("muted", ` (${r.agentSource})`)}`;
					if (isRunning) header += ` ${theme.fg("warning", "[running]")}`;
					if (isError && r.stopReason) header += ` ${theme.fg("error", `[${r.stopReason}]`)}`;
					container.addChild(new Text(header, 0, 0));
					container.addChild(new Text(theme.fg("dim", statusText), 0, 0));
					if (isError && r.errorMessage)
						container.addChild(new Text(theme.fg("error", `Error: ${r.errorMessage}`), 0, 0));
					container.addChild(new Spacer(1));
					container.addChild(new Text(theme.fg("muted", "─── Task ───"), 0, 0));
					container.addChild(new Text(theme.fg("dim", r.task), 0, 0));
					container.addChild(new Spacer(1));
					container.addChild(new Text(theme.fg("muted", "─── Output ───"), 0, 0));
					if (displayItems.length === 0 && !finalOutput) {
						container.addChild(new Text(theme.fg("muted", isRunning ? "(running...)" : "(no output)"), 0, 0));
					} else {
						for (const item of displayItems) {
							if (item.type === "toolCall")
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
						}
						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}
					}
					const usageStr = formatUsageStats(r.usage, r.model);
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", usageStr), 0, 0));
					}
					return container;
				}

				let text = `${icon} ${theme.fg("toolTitle", theme.bold(r.agent))}${theme.fg("muted", ` (${r.agentSource})`)}`;
				if (isRunning) text += ` ${theme.fg("warning", "[running]")}`;
				if (isError && r.stopReason) text += ` ${theme.fg("error", `[${r.stopReason}]`)}`;
				text += `\n${theme.fg("dim", statusText)}`;
				if (isError && r.errorMessage) text += `\n${theme.fg("error", `Error: ${r.errorMessage}`)}`;
				else if (displayItems.length === 0) text += `\n${theme.fg("muted", isRunning ? "(running...)" : "(no output)")}`;
				else {
					text += `\n${renderDisplayItems(displayItems, COLLAPSED_ITEM_COUNT)}`;
					if (displayItems.length > COLLAPSED_ITEM_COUNT) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				}
				const usageStr = formatUsageStats(r.usage, r.model);
				if (usageStr) text += `\n${theme.fg("dim", usageStr)}`;
				return new Text(text, 0, 0);
			}

			const aggregateUsage = (results: SingleResult[]) => {
				const total = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, turns: 0 };
				for (const r of results) {
					total.input += r.usage.input;
					total.output += r.usage.output;
					total.cacheRead += r.usage.cacheRead;
					total.cacheWrite += r.usage.cacheWrite;
					total.cost += r.usage.cost;
					total.turns += r.usage.turns;
				}
				return total;
			};

			if (details.mode === "chain") {
				const runningCount = details.results.filter((r) => isAgentRunning(r)).length;
				const successCount = details.results.filter((r) => !isAgentRunning(r) && r.exitCode === 0).length;
				const failCount = details.results.filter((r) => isAgentError(r)).length;
				const isRunning = runningCount > 0;
				const icon = isRunning
					? theme.fg("warning", "⏳")
					: failCount > 0
						? theme.fg("error", "✗")
						: theme.fg("success", "✓");
				const status = isRunning
					? `${successCount + failCount}/${details.results.length} done, ${runningCount} running`
					: `${successCount}/${details.results.length} steps`;

				if (expanded) {
					const container = new Container();
					container.addChild(
						new Text(
							icon + " " + theme.fg("toolTitle", theme.bold("chain ")) + theme.fg("accent", status),
							0,
							0,
						),
					);

					for (const r of details.results) {
						const rRunning = isAgentRunning(r);
						const rError = isAgentError(r);
						const rIcon = rRunning
							? theme.fg("warning", "⏳")
							: rError
								? theme.fg("error", "✗")
								: theme.fg("success", "✓");
						const displayItems = getDisplayItems(r.messages);
						const finalOutput = getFinalOutput(r.messages);
						const stepStatus = makeAgentStatusText(r);

						container.addChild(new Spacer(1));
						container.addChild(
							new Text(
								`${theme.fg("muted", `─── Step ${r.step}: `) + theme.fg("accent", r.agent)} ${rIcon}`,
								0,
								0,
							),
						);
						container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", r.task), 0, 0));
						container.addChild(new Text(theme.fg("dim", stepStatus), 0, 0));

						// Show tool calls
						for (const item of displayItems) {
							if (item.type === "toolCall") {
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
							}
						}

						// Show final output as markdown
						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}

						const stepUsage = formatUsageStats(r.usage, r.model);
						if (stepUsage) container.addChild(new Text(theme.fg("dim", stepUsage), 0, 0));
					}

					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", `Total: ${usageStr}`), 0, 0));
					}
					return container;
				}

				// Collapsed view
				let text = icon + " " + theme.fg("toolTitle", theme.bold("chain ")) + theme.fg("accent", status);
				for (const r of details.results) {
					const rRunning = isAgentRunning(r);
					const rError = isAgentError(r);
					const rIcon = rRunning
						? theme.fg("warning", "⏳")
						: rError
							? theme.fg("error", "✗")
							: theme.fg("success", "✓");
					const displayItems = getDisplayItems(r.messages);
					text += `\n\n${theme.fg("muted", `─── Step ${r.step}: `)}${theme.fg("accent", r.agent)} ${rIcon}`;
					text += `\n${theme.fg("dim", makeAgentStatusText(r))}`;
					if (displayItems.length === 0) text += `\n${theme.fg("muted", rRunning ? "(running...)" : "(no output)")}`;
					else text += `\n${renderDisplayItems(displayItems, 5)}`;
				}
				const usageStr = formatUsageStats(aggregateUsage(details.results));
				if (usageStr) text += `\n\n${theme.fg("dim", `Total: ${usageStr}`)}`;
				text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				return new Text(text, 0, 0);
			}

			if (details.mode === "parallel") {
				const running = details.results.filter((r) => isAgentRunning(r)).length;
				const successCount = details.results.filter((r) => !isAgentRunning(r) && r.exitCode === 0).length;
				const failCount = details.results.filter((r) => isAgentError(r)).length;
				const isRunning = running > 0;
				const icon = isRunning
					? theme.fg("warning", "⏳")
					: failCount > 0
						? theme.fg("warning", "◐")
						: theme.fg("success", "✓");
				const status = isRunning
					? `${successCount + failCount}/${details.results.length} done, ${running} running`
					: `${successCount}/${details.results.length} tasks`;

				if (expanded) {
					const container = new Container();
					container.addChild(
						new Text(
							`${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`,
							0,
							0,
						),
					);

					for (const r of details.results) {
						const rRunning = isAgentRunning(r);
						const rError = isAgentError(r);
						const rIcon = rRunning
							? theme.fg("warning", "⏳")
							: rError
								? theme.fg("error", "✗")
								: theme.fg("success", "✓");
						const displayItems = getDisplayItems(r.messages);
						const finalOutput = getFinalOutput(r.messages);

						container.addChild(new Spacer(1));
						container.addChild(
							new Text(`${theme.fg("muted", "─── ") + theme.fg("accent", r.agent)} ${rIcon}`, 0, 0),
						);
						container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", r.task), 0, 0));
						container.addChild(new Text(theme.fg("dim", makeAgentStatusText(r)), 0, 0));

						// Show tool calls
						for (const item of displayItems) {
							if (item.type === "toolCall") {
								container.addChild(
									new Text(
										theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, theme.fg.bind(theme)),
										0,
										0,
									),
								);
							}
						}

						// Show final output as markdown
						if (finalOutput) {
							container.addChild(new Spacer(1));
							container.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
						}

						const taskUsage = formatUsageStats(r.usage, r.model);
						if (taskUsage) container.addChild(new Text(theme.fg("dim", taskUsage), 0, 0));
					}

					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) {
						container.addChild(new Spacer(1));
						container.addChild(new Text(theme.fg("dim", `Total: ${usageStr}`), 0, 0));
					}
					return container;
				}

				// Collapsed view (or still running)
				let text = `${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`;
				for (const r of details.results) {
					const rRunning = isAgentRunning(r);
					const rError = isAgentError(r);
					const rIcon = rRunning
						? theme.fg("warning", "⏳")
						: rError
							? theme.fg("error", "✗")
							: theme.fg("success", "✓");
					const displayItems = getDisplayItems(r.messages);
					text += `\n\n${theme.fg("muted", "─── ")}${theme.fg("accent", r.agent)} ${rIcon}`;
					text += `\n${theme.fg("dim", makeAgentStatusText(r))}`;
					if (displayItems.length === 0) text += `\n${theme.fg("muted", rRunning ? "(running...)" : "(no output)")}`;
					else text += `\n${renderDisplayItems(displayItems, 5)}`;
				}
				if (!isRunning) {
					const usageStr = formatUsageStats(aggregateUsage(details.results));
					if (usageStr) text += `\n\n${theme.fg("dim", `Total: ${usageStr}`)}`;
				}
				if (!expanded) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				return new Text(text, 0, 0);
			}

			const text = result.content[0];
			return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
		},
	});
}
