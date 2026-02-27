# Example: Single AI (Codex Only)

Demonstrates `/so codex "question"` — getting one response from Codex.

## Input

```
/so codex "What's the best approach for implementing a rate limiter in Go?"
```

## Workflow

1. **Parse Arguments**
   - AI_SPEC: `codex`
   - QUESTION: "What's the best approach for implementing a rate limiter in Go?"

2. **Pre-flight Evaluation**
   - Question is specific and self-contained
   - No codebase context needed (general programming)
   - Mode: `general`

3. **Invoke /complete-prompt**
   ```
   Skill tool: complete-prompt
   Args: "general"
   ```
   Output: `.prompts/20260205-143022-general.xml`

4. **Spawn Coordinator**
   Single sub-agent for Codex thorough model.

5. **Raw Response**

```
## CODEX (gpt-5.2-codex) ##
────────────────────────────────────────
For a rate limiter in Go, I recommend the token bucket algorithm. Here's a clean implementation:

1. **Use `golang.org/x/time/rate`** - The standard approach
   ```go
   limiter := rate.NewLimiter(rate.Limit(10), 100) // 10 req/sec, burst of 100
   if !limiter.Allow() {
       return errors.New("rate limited")
   }
   ```

2. **For distributed systems**, use Redis + Lua scripts for atomic operations.

3. **Consider sliding window** for more accurate rate limiting at window boundaries.

Key tradeoffs:
- Token bucket: Simple, allows bursts, but can spike at refill
- Sliding window: More accurate, but more memory/computation
- Leaky bucket: Smoothest output, but may delay legitimate traffic
────────────────────────────────────────
📁 Saved: .responses/codex-gpt-5.2-codex-20260205-143025.txt
```

6. **Synthesis**

```
## MY SYNTHESIS ##
────────────────────────────────────────
Codex recommends the token bucket algorithm via `golang.org/x/time/rate` for
single-instance rate limiting. For your use case:

- **Single server**: Use `rate.NewLimiter` directly
- **Distributed**: Redis-based solution with Lua scripts

The tradeoff analysis is helpful — token bucket is the pragmatic default.
────────────────────────────────────────
```

## Key Points

- Single AI mode is useful for quick questions or when you want a specific AI's perspective
- Synthesis is still provided even with one response (adds Claude's analysis)
- Response is saved for later reference
