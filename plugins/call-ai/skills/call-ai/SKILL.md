---
name: call-ai
description: Run a prompt against external AIs (Codex, Gemini, Claude). Low-level building block for other skills. Use for "ask codex", "ask gemini", "call AI", or when delegating prompts to external models.
argument-hint: "[codex|gemini|claude|:all] \"prompt\""
user-invocable: true
---

# Call AI

Run a prompt against external AI providers. This is a low-level building block skill.

**Alias:** `/ca`

**Usage:**
- `/call-ai "prompt"` — Run against Codex + Gemini thorough models (default)
- `/call-ai :all "prompt"` — Run against all 6 models
- `/call-ai codex "prompt"` — Codex thorough only
- `/call-ai gemini "prompt"` — Gemini thorough only
- `/call-ai claude "prompt"` — Claude sub-agent (fresh context)

---

## Pre-flight Checklist

Before invoking `/call-ai`:

- [ ] **Prompt is self-contained** — No implicit context; external AIs have zero conversation history
- [ ] **Expected format is clear** — Tell the AI what output structure you expect
- [ ] **AI selection matches task** — Use thorough models for complex analysis, fast for simple queries
- [ ] **File path provided for large prompts** — Use `-f` flag if prompt exceeds 4K characters
- [ ] **CLI tools installed** — Verify: `which codex gemini claude`

**Quick validation:**
```bash
# Check CLI availability
for cli in codex gemini claude; do command -v $cli &>/dev/null && echo "✓ $cli" || echo "✗ $cli missing"; done

# Check prompt file (if using -f)
[[ -f "$PROMPT_FILE" ]] && echo "✓ Prompt: $(wc -c < "$PROMPT_FILE") chars" || echo "✗ File not found"
```

---

## Zellij Pane Mode

When running inside [Zellij](https://zellij.dev/), `ask-ai-zellij.sh` launches each AI CLI in a **stacked pane** so you can watch responses stream in real-time. This is auto-detected via the `$ZELLIJ` environment variable — no configuration needed.

### How It Works

1. `ask-ai-zellij.sh` creates a stacked pane running `scripts/zellij-ai-pane.sh`
2. The pane shows a colored banner, streams the AI response live via `tee`, and displays a footer with stats
3. The parent script polls a `.done` sentinel file until the pane completes
4. Metrics and output are returned in the same format as `ask-ai.sh`

### Fallback

When `$ZELLIJ` is **not set** (plain terminal, tmux, etc.), `ask-ai-zellij.sh` transparently falls back to `ask-ai.sh` — no behavior change.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ZELLIJ_AI_MAX_TIMEOUT` | `1800` | Max wall-clock seconds before killing pane (safety net) |
| `ZELLIJ_AI_PANE_HOLD` | `30` | Seconds to keep pane open after successful completion |
| `ZELLIJ_AI_PANE_HOLD_ON_ERROR` | `60` | Seconds to keep pane open after failure |

### Pane Interaction

During the hold period after completion, you can press:
- **`q`** — Close the pane immediately
- **`k`** — Keep the pane open indefinitely (close manually)

### Pane Visual

```
╭─── CODEX (gpt-5.3-codex) ───────────────────────────────────╮
│ Started: 14:32:05 | Prompt: 2,847 chars                      │
╰──────────────────────────────────────────────────────────────╯

[streaming AI response appears here in real-time...]

╭─── Complete ─────────────────────────────────────────────────╮
│ Duration: 12.3s | Response: 4,521 chars | Exit: 0            │
╰──────────────────────────────────────────────────────────────╯
Closing in 28s... (q=close, k=keep)
```

---

## Parallel Execution

`scripts/run-parallel.sh` runs multiple AI calls simultaneously, collecting all results.

**Usage:**
```bash
scripts/run-parallel.sh <prompt-file> <ai1> <model1> [<ai2> <model2> ...]
```

**Examples:**
```bash
# Two AIs (default for /second-opinion)
scripts/run-parallel.sh prompt.xml codex gpt-5.3-codex gemini gemini-3-pro-preview

# All 6 models
scripts/run-parallel.sh prompt.xml codex gpt-5.3-codex codex gpt-5.2-codex gemini gemini-3-pro-preview gemini gemini-3-flash-preview claude sonnet claude haiku
```

**How it works:**
1. Launches each `ask-ai-zellij.sh` as a background process
2. In Zellij: each AI gets its own stacked pane (6 streaming panes visible simultaneously)
3. Outside Zellij: falls back to headless `ask-ai.sh`
4. Monitors PID liveness per-process — lets processes run as long as they're alive (AI CLIs handle their own timeouts)
5. Safety net: kills any process exceeding the max wall-clock timeout (default: 30 min)
6. Outputs collected results with `=== RESULT: <ai> <model> ===` / `=== END ===` delimiters

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AI_MAX_TIMEOUT` | `1800` | Max wall-clock seconds before killing a process (safety net) |
| `AI_POLL_INTERVAL` | `3` | Seconds between liveness checks |

---

## Error Handling

Retries (3x with 10s/20s/40s backoff + jitter) are handled internally by `ask-ai.sh` / `zellij-ai-pane.sh`. When using `run-parallel.sh`, each AI process manages its own retries independently. Callers see only final success/failure per AI.

| Error | Cause | Recovery (automatic) |
|-------|-------|----------|
| CLI timeout | Slow response, network | Retried internally (3x with backoff) |
| Empty response | API error | Logged as failure |
| Rate limit (429) | Too many requests | Retried internally with jitter |
| Wall-clock timeout | Process running >30min | Process killed by safety net |
| File not found | Prompt missing | Immediate error, no retry |

### Graceful Degradation

- **1 AI fails:** Return successful responses + failure note
- **All AIs fail:** Return error summary with troubleshooting
- **Never fail silently** — always report what happened

### Failure Output Format

```
## CODEX (gpt-5.3-codex) ##
────────────────────────────────────────
[Raw response]
────────────────────────────────────────

## GEMINI (gemini-3-pro-preview) ##
────────────────────────────────────────
⚠️ FAILED: Connection timeout
   Troubleshooting: Check network, verify API key in Keychain
────────────────────────────────────────
```

### Troubleshooting Reference

| Symptom | Likely Cause | Check / Fix |
|---------|--------------|-------------|
| All AIs timeout | Network/VPN issue | `ping api.openai.com`, check VPN status |
| 401/403 errors | Invalid/expired API key | `security find-generic-password -s "codex-api-key" -w` |
| Empty responses | API error or prompt too large | Check `.responses/*.err` files; reduce prompt size |
| Partial failures | Rate limiting | Wait 60s and retry single AI: `/call-ai codex "test"` |
| "missing_cli" error | CLI not installed | `brew install codex` / `pip install gemini-cli` |
| "context_length" error | Prompt exceeds model limit | Use brief mode or split prompt |
| Slow responses (>60s) | Model overloaded | Try fast variant or different provider |

**Debug commands:**
```bash
# Check recent errors
ls -la .responses/*.err 2>/dev/null | tail -5

# View last response metrics
cat .responses/*.metrics.json | tail -1 | jq .

# Check API key exists (Codex example)
security find-generic-password -s "codex-api-key" &>/dev/null && echo "✓ Key exists" || echo "✗ Key missing"

# Test single AI
./ask-ai-zellij.sh codex gpt-5.3-codex "Say hello"
```
