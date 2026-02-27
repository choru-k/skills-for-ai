# All Models Invocation (:all)

Examples of invoking `/call-ai :all` for comprehensive multi-AI review.

## Basic Usage

```
/call-ai :all "What are the security implications of storing JWTs in localStorage vs httpOnly cookies?"
```

**What happens:**
1. Spawns 6 sub-agents in parallel:
   - Codex thorough (gpt-5.2-codex)
   - Codex fast (gpt-5.1-codex-mini)
   - Gemini thorough (gemini-3-pro-preview)
   - Gemini fast (gemini-3-flash-preview)
   - Claude thorough (sonnet)
   - Claude fast (haiku)
2. All run concurrently
3. Returns 6 raw responses

## Via /second-opinion (Recommended)

```
/so :all "Review the authentication architecture"
```

This adds:
- Automatic context generation
- Response quality verification
- Intelligent synthesis (consensus detection, divergence highlighting)

## Expected Output

```
## CODEX (gpt-5.2-codex) ##
────────────────────────────────────────
[Thorough analysis...]
────────────────────────────────────────

## CODEX (gpt-5.1-codex-mini) ##
────────────────────────────────────────
[Faster, more concise response...]
────────────────────────────────────────

## GEMINI (gemini-3-pro-preview) ##
────────────────────────────────────────
[Thorough analysis...]
────────────────────────────────────────

## GEMINI (gemini-3-flash-preview) ##
────────────────────────────────────────
[Faster response...]
────────────────────────────────────────

## CLAUDE (sonnet) ##
────────────────────────────────────────
[Thorough analysis...]
────────────────────────────────────────

## CLAUDE (haiku) ##
────────────────────────────────────────
[Fast, concise response...]
────────────────────────────────────────
```

## When to Use :all

| Scenario | Use :all? |
|----------|-----------|
| Critical architecture decisions | ✅ Yes |
| Security review | ✅ Yes |
| Controversial design choice | ✅ Yes (consensus = confidence) |
| Quick factual question | ❌ No (overkill) |
| Time-sensitive task | ❌ No (takes 2-5 min) |
| Cost-sensitive | ❌ No (6x API calls) |

## Interpreting Results

### Strong Consensus (All 6 Agree)
```
All models recommend using httpOnly cookies for JWT storage due to XSS protection.
```
**Interpretation:** High confidence in the recommendation.

### Thorough vs Fast Split
```
Thorough models: Detailed analysis with edge cases
Fast models: "Agree with above" or simplified version
```
**Interpretation:** Fast models validate thorough analysis.

### Provider Disagreement
```
Codex: Recommends localStorage with CSP
Gemini: Recommends httpOnly cookies
Claude: Recommends hybrid approach
```
**Interpretation:** Complex tradeoff—dig deeper into each perspective.

## Timing Expectations

| Scenario | Typical Duration |
|----------|-----------------|
| All succeed first try | 60-90 seconds |
| Some retries needed | 2-3 minutes |
| Multiple failures | 3-5 minutes |
| All fail (network down) | ~4 minutes (retry exhaustion) |

## Files Generated

After `:all` invocation:
```bash
ls -la .responses/ | grep "$(date +%Y%m%d)" | wc -l
# Expected: 6 response files + 6 metrics files = 12 files
```
