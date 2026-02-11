# Multi-AI Invocation (Default)

Examples of the default `/call-ai` behavior: Codex + Gemini thorough models.

## Basic Usage

```
/call-ai "What's the best way to handle database migrations in a microservices architecture?"
```

**What happens:**
1. Spawns 2 sub-agents in parallel:
   - Codex thorough (gpt-5.2-codex)
   - Gemini thorough (gemini-3-pro-preview)
2. Both run concurrently via `ask-ai.sh`
3. Returns both responses (no synthesis)

## Via /second-opinion (Recommended)

```
/so "Should we use event sourcing for the order service?"
```

This:
1. Generates context via `/complete-prompt`
2. Invokes `/call-ai` with the prompt file
3. Synthesizes responses (merges/compares)

## Expected Output

```
## CODEX (gpt-5.2-codex) ##
────────────────────────────────────────
Event sourcing is well-suited for order services because...
[detailed response]
────────────────────────────────────────
📁 Saved: .responses/codex-gpt-5.2-codex-20260205-143022.txt

## GEMINI (gemini-3-pro-preview) ##
────────────────────────────────────────
For an order service, consider these tradeoffs...
[detailed response]
────────────────────────────────────────
📁 Saved: .responses/gemini-gemini-3-pro-preview-20260205-143025.txt
```

## Why Default is 2 AIs?

| Factor | Rationale |
|--------|-----------|
| **Speed** | 2 AIs complete in ~30-60s vs ~2-3min for all 6 |
| **Diversity** | Codex (OpenAI) + Gemini (Google) = different training data |
| **Cost** | Thorough models only (no fast variants) |
| **Signal** | If both agree → high confidence; if disagree → worth investigating |

## Partial Failure Handling

If one AI fails:

```
## CODEX (gpt-5.2-codex) ##
────────────────────────────────────────
[Response]
────────────────────────────────────────

## GEMINI (gemini-3-pro-preview) ##
────────────────────────────────────────
⚠️ FAILED after 3 retries: Rate limit exceeded
   Last attempt: 2026-02-05 14:32:15
   Troubleshooting: Wait 60s and retry
────────────────────────────────────────
```

The successful response is still returned.
