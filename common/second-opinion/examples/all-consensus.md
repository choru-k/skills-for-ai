# Example: All Mode with Consensus

Demonstrates `/so :all "question"` — getting 6 responses from all 3 AIs with both thorough and fast variants.

## Input

```
/so :all "Is it worth migrating from REST to GraphQL for our public API?"
```

## Workflow

1. **Parse Arguments**
   - AI_SPEC: `:all`
   - QUESTION: "Is it worth migrating from REST to GraphQL for our public API?"

2. **Pre-flight Evaluation**
   - Question is architectural and benefits from multiple perspectives
   - Codebase context would help understand current API structure
   - Mode: `architect`

3. **Invoke /complete-prompt**
   ```
   Skill tool: complete-prompt
   Args: "architect"
   ```
   Output: `.prompts/20260205-160512-architect.xml`

4. **Spawn Coordinator**
   Six parallel sub-agents:
   - Codex thorough + fast
   - Gemini thorough + fast
   - Claude thorough + fast

5. **Raw Responses**

```
## CODEX (gpt-5.2-codex) [thorough] ##
────────────────────────────────────────
For a public API migration from REST to GraphQL, consider:

**Against migration:**
- Public APIs need stability; GraphQL adds learning curve for consumers
- REST is universally understood; GraphQL requires client library investment
- Caching is simpler with REST (HTTP caching works out of the box)

**For migration:**
- Reduces over-fetching for mobile clients
- Single endpoint simplifies versioning
- Strong typing improves developer experience

**Verdict:** For a *public* API, I'd recommend keeping REST. GraphQL shines
for internal or first-party apps where you control the client.
────────────────────────────────────────

## CODEX (gpt-5.1-codex-mini) [fast] ##
────────────────────────────────────────
Keep REST for public APIs. GraphQL is better for internal use where you
control both client and server.
────────────────────────────────────────

## GEMINI (gemini-3-pro-preview) [thorough] ##
────────────────────────────────────────
Migration ROI depends heavily on your consumer base:

**Keep REST if:**
- API consumers are diverse (many languages/platforms)
- You have extensive documentation and client libraries
- Consumers prefer simplicity over flexibility

**Consider GraphQL if:**
- Mobile-first consumers need precise data fetching
- You're struggling with API versioning
- Internal teams would benefit from self-service querying

**Hybrid approach:** Offer both. REST for broad compatibility, GraphQL
for power users. Facebook does this.
────────────────────────────────────────

## GEMINI (gemini-3-flash-preview) [fast] ##
────────────────────────────────────────
For public APIs, REST is usually better. Consider hybrid: REST primary,
GraphQL as optional power-user endpoint.
────────────────────────────────────────

## CLAUDE (sonnet) [thorough] ##
────────────────────────────────────────
I'd recommend against a full migration for these reasons:

1. **Public API consumers expect REST** — It's the lingua franca
2. **Breaking change** — Existing integrations would need rewriting
3. **Caching complexity** — GraphQL requires custom caching strategies

However, you could:
- Add GraphQL as an *additional* endpoint
- Use GraphQL internally while exposing REST externally
- Evaluate based on actual consumer feedback

The "migration" framing assumes replacement. Consider "addition" instead.
────────────────────────────────────────

## CLAUDE (haiku) [fast] ##
────────────────────────────────────────
Don't migrate a public API from REST to GraphQL. Add GraphQL alongside
REST if there's demand, but keep REST as primary.
────────────────────────────────────────
```

6. **Verification**
   - 6 responses received ✓
   - All responses substantial ✓
   - No truncation ✓

7. **Synthesis**

```
## FULL CONSENSUS: ALL MODELS ##
────────────────────────────────────────
All 6 responses (3 AIs × 2 variants) reached the same conclusion:

**Do not migrate a public API from REST to GraphQL.**

Reasons cited by all:
- REST is the standard for public APIs
- Migration is a breaking change for consumers
- GraphQL's benefits don't outweigh costs for external APIs
────────────────────────────────────────

## UNIQUE INSIGHT: HYBRID APPROACH ##
────────────────────────────────────────
Gemini and Claude thorough models suggested a hybrid strategy:
- Keep REST as the primary public API
- Offer GraphQL as an optional endpoint for power users
- Use GraphQL internally while exposing REST externally

This "addition not migration" framing reframes the question productively.
────────────────────────────────────────

## FAST MODELS ##
────────────────────────────────────────
⬆️ All fast models agreed with thorough models. No divergent opinions.
────────────────────────────────────────

## MY SYNTHESIS ##
────────────────────────────────────────
**Strong consensus: Keep REST for your public API.**

The unanimity here is notable — even with 6 different responses, all converged
on the same recommendation. This suggests high confidence in the answer.

**Actionable next step:** If you're feeling pressure to offer GraphQL, survey
your API consumers. The hybrid approach (REST primary + GraphQL optional) is
a safe middle ground that doesn't break existing integrations.
────────────────────────────────────────
```

## Key Points

- `:all` mode provides maximum coverage (6 responses) for high-stakes decisions
- When all models agree, this indicates high confidence in the answer
- Fast models serve as a "sanity check" — if they diverge from thorough models, something interesting is happening
- The synthesis format changes based on consensus level:
  - Full consensus → grouped output (shown once)
  - Partial consensus → show divergent responses separately
  - Unique insights → always highlighted even in consensus
