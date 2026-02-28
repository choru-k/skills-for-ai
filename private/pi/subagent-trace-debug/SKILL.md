---
name: subagent-trace-debug
description: Find and debug Pi subagent trace runs quickly. Use for "debug subagent trace", "latest reviewer tree", "why did reviewer fail", "trace rootInvocationId", or "analyze subagent logs".
user-invocable: true
allowed-tools: Bash, Read, AskUserQuestion
---

# Subagent Trace Debug

Use this skill to analyze Pi subagent trace logs with the helper script:

- Script: `~/.pi/agent/scripts/subagent-trace.py`
- Default trace: `~/.pi/agent/logs/subagent-trace.jsonl`

## Quick Commands

```bash
# Recent roots
~/.pi/agent/scripts/subagent-trace.py roots --limit 10

# Latest reviewer root id
~/.pi/agent/scripts/subagent-trace.py latest --agent reviewer --id-only

# Tree
~/.pi/agent/scripts/subagent-trace.py tree <rootInvocationId> --runs

# Full debug summary
~/.pi/agent/scripts/subagent-trace.py debug <rootInvocationId>
```

## Workflow

1. If user did not provide a root id, resolve one with `latest`:
   - prefer `--agent reviewer` when context is reviewer-team gate.
2. Run `tree` for structure and sequencing.
3. Run `debug` for failures, slowest specialists, cumulative timings, overhead, and slow tools.
4. Return:
   - invocation tree,
   - slowest specialist (single + cumulative),
   - concrete failure cause and timing evidence.

## Guardrails

- Treat trace file as source of truth.
- Cite evidence with IDs, elapsedMs, and (when useful) trace line numbers from script output.
- If trace appears incomplete (active run), call that out explicitly.
- Do not edit trace logs.
