#!/usr/bin/env python3

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

DEFAULT_TRACE = Path.home() / ".pi" / "agent" / "logs" / "subagent-trace.jsonl"


def fmt_ms(value):
    if value is None:
        return "-"
    try:
        ms = int(value)
    except (TypeError, ValueError):
        return "-"
    if ms < 1000:
        return f"{ms}ms"
    seconds = ms / 1000.0
    if seconds < 60:
        return f"{seconds:.1f}s"
    minutes = seconds / 60.0
    if minutes < 60:
        return f"{minutes:.1f}m"
    hours = minutes / 60.0
    return f"{hours:.1f}h"


def classify_error(stderr_tail):
    text = (stderr_tail or "").lower()
    if not text:
        return ""
    if "no api key found" in text:
        return "No API key found"
    if "lock file is already being held" in text:
        return "Lock file already held"
    if "fetch failed" in text:
        return "fetch failed"
    if "unknown tool" in text:
        return "unknown tool"
    return "error"


def load_events(path):
    events = []
    try:
        with path.open("r", encoding="utf-8") as handle:
            for line_no, line in enumerate(handle, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                event["_line"] = line_no
                events.append(event)
    except FileNotFoundError:
        print(f"trace file not found: {path}", file=sys.stderr)
        sys.exit(1)
    return events


def collect_roots(events):
    roots = {}
    for event in events:
        invocation_id = event.get("invocationId")
        root_id = event.get("rootInvocationId") or invocation_id
        event_name = event.get("event")

        if invocation_id == root_id and event_name == "subagent_invocation_start":
            requested = event.get("requestedAgents") or []
            roots.setdefault(root_id, {
                "rootId": root_id,
                "startLine": event["_line"],
                "startTs": event.get("timestamp"),
                "mode": event.get("mode"),
                "agent": requested[0] if requested else event.get("agent", "-"),
                "status": "running",
                "elapsedMs": None,
                "childInvocations": 0,
                "childRuns": 0,
                "childFailures": 0,
            })

        if root_id not in roots:
            continue

        root = roots[root_id]
        if invocation_id == root_id and event_name == "subagent_run_end":
            root["status"] = event.get("status", root["status"])
            root["elapsedMs"] = event.get("elapsedMs", root["elapsedMs"])
            root["endLine"] = event["_line"]
            root["endTs"] = event.get("timestamp")
        elif invocation_id == root_id and event_name == "subagent_invocation_end":
            root["status"] = event.get("status", root["status"])
            root["elapsedMs"] = event.get("elapsedMs", root["elapsedMs"])
            root["endLine"] = event["_line"]
            root["endTs"] = event.get("timestamp")
        elif event_name == "subagent_invocation_start" and invocation_id != root_id:
            root["childInvocations"] += 1
        elif event_name == "subagent_run_end" and event.get("depth", 0) > 0:
            root["childRuns"] += 1
            if event.get("status") != "success":
                root["childFailures"] += 1

    return roots


def build_root_index(events, root_id):
    invocations = {}
    run_tool_sum = defaultdict(int)
    tool_events = []

    for event in events:
        if event.get("rootInvocationId") != root_id and event.get("invocationId") != root_id:
            continue

        invocation_id = event.get("invocationId")
        if not invocation_id:
            continue

        info = invocations.setdefault(invocation_id, {
            "invocationId": invocation_id,
            "runs": [],
            "requestedAgents": [],
        })

        event_name = event.get("event")
        if event_name == "subagent_invocation_start":
            info.update({
                "startLine": event["_line"],
                "startTs": event.get("timestamp"),
                "mode": event.get("mode"),
                "depth": event.get("depth"),
                "parentInvocationId": event.get("parentInvocationId"),
                "parentRunId": event.get("parentRunId"),
                "requestedAgents": event.get("requestedAgents") or [],
            })
            if info.get("mode") == "single" and info["requestedAgents"] and not info.get("agent"):
                info["agent"] = info["requestedAgents"][0]
        elif event_name == "subagent_single_start":
            if event.get("agent"):
                info["agent"] = event.get("agent")
        elif event_name == "subagent_parallel_start":
            info["parallelTaskCount"] = event.get("taskCount")
        elif event_name == "subagent_invocation_end":
            info.update({
                "status": event.get("status", info.get("status")),
                "elapsedMs": event.get("elapsedMs", info.get("elapsedMs")),
                "endLine": event["_line"],
                "endTs": event.get("timestamp"),
                "taskCount": event.get("taskCount", info.get("taskCount")),
                "successCount": event.get("successCount", info.get("successCount")),
            })
            if event.get("agent") and not info.get("agent"):
                info["agent"] = event.get("agent")
        elif event_name == "subagent_run_end":
            run = {
                "line": event["_line"],
                "timestamp": event.get("timestamp"),
                "runId": event.get("runId"),
                "agent": event.get("agent"),
                "status": event.get("status"),
                "elapsedMs": event.get("elapsedMs"),
                "depth": event.get("depth"),
                "stderrTail": event.get("stderrTail", ""),
            }
            info["runs"].append(run)
            if event.get("status") and not info.get("status"):
                info["status"] = event.get("status")
            if event.get("elapsedMs") is not None and info.get("elapsedMs") is None:
                info["elapsedMs"] = event.get("elapsedMs")
            if event.get("agent") and not info.get("agent"):
                info["agent"] = event.get("agent")
        elif event_name == "subagent_tool_end":
            run_id = event.get("runId")
            if run_id:
                try:
                    run_tool_sum[run_id] += int(event.get("elapsedMs") or 0)
                except (TypeError, ValueError):
                    pass
            if event.get("depth", 0) >= 1:
                tool_events.append({
                    "line": event["_line"],
                    "invocationId": invocation_id,
                    "runId": run_id,
                    "agent": event.get("agent"),
                    "elapsedMs": event.get("elapsedMs") or 0,
                    "toolName": event.get("toolName"),
                    "toolSummary": event.get("toolSummary"),
                })

    if root_id not in invocations:
        return {}, {}, []

    # Backfill root status from run when invocation_end is missing
    root_info = invocations[root_id]
    if root_info.get("status") is None and root_info.get("runs"):
        latest_run = sorted(root_info["runs"], key=lambda r: r["line"])[-1]
        root_info["status"] = latest_run.get("status")
        root_info["elapsedMs"] = latest_run.get("elapsedMs")

    return invocations, run_tool_sum, tool_events


def build_children(invocations, root_id):
    children = defaultdict(list)
    for invocation_id, info in invocations.items():
        if invocation_id == root_id:
            continue
        parent = info.get("parentInvocationId") or root_id
        children[parent].append(invocation_id)
    for parent in list(children):
        children[parent].sort(key=lambda item: invocations[item].get("startLine", 10**12))
    return children


def invocation_label(info):
    mode = info.get("mode") or "?"
    if mode == "parallel":
        agent = "parallel"
    else:
        agent = info.get("agent") or ",".join(info.get("requestedAgents") or []) or "-"

    status = info.get("status") or "running"
    elapsed = fmt_ms(info.get("elapsedMs"))

    if mode == "parallel":
        task_count = info.get("taskCount")
        if task_count is None:
            task_count = info.get("parallelTaskCount")
        success_count = info.get("successCount")
        if success_count is not None and task_count is not None:
            return f"{agent} [{mode}, {status}, {elapsed}, success {success_count}/{task_count}]"
    return f"{agent} [{mode}, {status}, {elapsed}]"


def print_tree(invocations, root_id, include_runs=False):
    children = build_children(invocations, root_id)

    root_info = invocations[root_id]
    print(f"{root_id} {invocation_label(root_info)}")

    def walk(parent_id, prefix):
        run_items = []
        if include_runs:
            runs = sorted(invocations[parent_id].get("runs", []), key=lambda r: r["line"])
            for run in runs:
                if parent_id == root_id and run.get("depth", 0) == 0:
                    continue
                run_items.append(("run", run))

        child_items = [("child", child_id) for child_id in children.get(parent_id, [])]
        items = run_items + child_items

        for index, (kind, payload) in enumerate(items):
            is_last = index == len(items) - 1
            branch = "└─ " if is_last else "├─ "

            if kind == "run":
                run = payload
                error_label = classify_error(run.get("stderrTail", ""))
                line = (
                    f"run {run.get('agent', '-')} "
                    f"[{run.get('status', 'running')}, {fmt_ms(run.get('elapsedMs'))}]"
                )
                if error_label:
                    line += f" ({error_label})"
                print(f"{prefix}{branch}{line}")
                continue

            child_id = payload
            child_info = invocations[child_id]
            print(f"{prefix}{branch}{child_id} {invocation_label(child_info)}")
            child_prefix = prefix + ("   " if is_last else "│  ")
            walk(child_id, child_prefix)

    walk(root_id, "")


def cmd_roots(args):
    events = load_events(args.trace)
    roots = collect_roots(events)

    rows = sorted(roots.values(), key=lambda row: row.get("startLine", 0), reverse=True)
    if args.agent:
        target = args.agent.lower()
        rows = [row for row in rows if target in (row.get("agent", "").lower())]

    if not rows:
        print("no matching root invocations found")
        return

    print("START (UTC)               AGENT           STATUS            ELAPSED   FAIL/RUNS  ROOT")
    for row in rows[: args.limit]:
        child_runs = row.get("childRuns", 0)
        child_failures = row.get("childFailures", 0)
        print(
            f"{(row.get('startTs') or '-'):24} "
            f"{(row.get('agent') or '-'):15.15} "
            f"{(row.get('status') or '-'):16.16} "
            f"{fmt_ms(row.get('elapsedMs')):8} "
            f"{child_failures}/{child_runs:7} "
            f"{row.get('rootId')}"
        )


def cmd_latest(args):
    events = load_events(args.trace)
    roots = collect_roots(events)

    rows = sorted(roots.values(), key=lambda row: row.get("startLine", 0), reverse=True)
    if args.agent:
        target = args.agent.lower()
        rows = [row for row in rows if target in (row.get("agent", "").lower())]

    if not rows:
        print("no matching root invocations found", file=sys.stderr)
        sys.exit(1)

    row = rows[0]
    if args.id_only:
        print(row["rootId"])
        return

    print(f"root:    {row['rootId']}")
    print(f"agent:   {row.get('agent', '-')}")
    print(f"status:  {row.get('status', '-')}")
    print(f"elapsed: {fmt_ms(row.get('elapsedMs'))}")
    print(f"start:   {row.get('startTs', '-')}")
    print(f"failures:{row.get('childFailures', 0)}/{row.get('childRuns', 0)} child runs")


def cmd_tree(args):
    events = load_events(args.trace)
    invocations, _, _ = build_root_index(events, args.root)
    if args.root not in invocations:
        print(f"root invocation not found: {args.root}", file=sys.stderr)
        sys.exit(1)
    print_tree(invocations, args.root, include_runs=args.runs)


def cmd_debug(args):
    events = load_events(args.trace)
    invocations, run_tool_sum, tool_events = build_root_index(events, args.root)
    if args.root not in invocations:
        print(f"root invocation not found: {args.root}", file=sys.stderr)
        sys.exit(1)

    print_tree(invocations, args.root, include_runs=True)

    runs = []
    for invocation in invocations.values():
        runs.extend(invocation.get("runs", []))

    child_runs = [run for run in runs if (run.get("depth") or 0) >= 1]
    failures = [run for run in child_runs if run.get("status") != "success"]

    print("\nFailures")
    if not failures:
        print("- none")
    else:
        for run in sorted(failures, key=lambda item: item["line"]):
            error_label = classify_error(run.get("stderrTail", ""))
            suffix = f" ({error_label})" if error_label else ""
            print(
                f"- {run['line']}: {run.get('agent', '-')} "
                f"[{run.get('status', 'running')}, {fmt_ms(run.get('elapsedMs'))}]{suffix}"
            )

    success_runs = [run for run in child_runs if run.get("status") == "success"]

    print("\nSlowest specialist attempts")
    if not success_runs:
        print("- none")
    else:
        top = sorted(success_runs, key=lambda item: item.get("elapsedMs") or 0, reverse=True)[:5]
        for run in top:
            print(
                f"- {run.get('agent', '-')}: {fmt_ms(run.get('elapsedMs'))} "
                f"(invocation {next((iid for iid, info in invocations.items() if run in info.get('runs', [])), '-')})"
            )

    cumulative = defaultdict(int)
    for run in child_runs:
        cumulative[run.get("agent") or "-"] += int(run.get("elapsedMs") or 0)

    print("\nCumulative by specialist")
    if not cumulative:
        print("- none")
    else:
        for agent, total in sorted(cumulative.items(), key=lambda item: item[1], reverse=True):
            print(f"- {agent}: {fmt_ms(total)}")

    print("\nRun overhead (elapsed - tool time)")
    if not success_runs:
        print("- none")
    else:
        rows = []
        for run in success_runs:
            run_id = run.get("runId")
            elapsed = int(run.get("elapsedMs") or 0)
            tool_time = int(run_tool_sum.get(run_id, 0))
            rows.append((elapsed - tool_time, elapsed, tool_time, run))
        for non_tool, elapsed, tool_time, run in sorted(rows, reverse=True)[:5]:
            print(
                f"- {run.get('agent', '-')}: non-tool {fmt_ms(non_tool)} "
                f"(elapsed {fmt_ms(elapsed)}, tools {fmt_ms(tool_time)})"
            )

    slow_tools = sorted(tool_events, key=lambda item: int(item.get("elapsedMs") or 0), reverse=True)
    slow_tools = [tool for tool in slow_tools if int(tool.get("elapsedMs") or 0) >= args.min_tool_ms][:5]

    print(f"\nSlow tools (>= {args.min_tool_ms}ms)")
    if not slow_tools:
        print("- none")
    else:
        for tool in slow_tools:
            print(
                f"- {tool['line']}: {tool.get('agent', '-')} {tool.get('toolName', '-')} "
                f"[{fmt_ms(tool.get('elapsedMs'))}] {tool.get('toolSummary', '')}"
            )


def parse_args():
    parser = argparse.ArgumentParser(description="Subagent trace finder/debugger")
    parser.add_argument(
        "--trace",
        type=Path,
        default=DEFAULT_TRACE,
        help=f"path to trace JSONL (default: {DEFAULT_TRACE})",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    roots = subparsers.add_parser("roots", help="list recent root invocations")
    roots.add_argument("--limit", type=int, default=10, help="max rows (default: 10)")
    roots.add_argument("--agent", help="filter by root agent (substring)")
    roots.set_defaults(func=cmd_roots)

    latest = subparsers.add_parser("latest", help="show latest root invocation")
    latest.add_argument("--agent", help="filter by root agent (substring)")
    latest.add_argument("--id-only", action="store_true", help="print only rootInvocationId")
    latest.set_defaults(func=cmd_latest)

    tree = subparsers.add_parser("tree", help="print invocation tree for one root")
    tree.add_argument("root", help="rootInvocationId")
    tree.add_argument("--runs", action="store_true", help="include subagent_run_end rows")
    tree.set_defaults(func=cmd_tree)

    debug = subparsers.add_parser("debug", help="tree + failures + bottlenecks")
    debug.add_argument("root", help="rootInvocationId")
    debug.add_argument("--min-tool-ms", type=int, default=500, help="slow tool threshold (default: 500)")
    debug.set_defaults(func=cmd_debug)

    return parser.parse_args()


def main():
    args = parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
