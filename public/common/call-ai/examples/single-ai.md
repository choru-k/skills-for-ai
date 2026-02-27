# Single AI Invocation

Examples of invoking `/call-ai` with a single AI provider.

## Basic Usage

### Codex Only
```
/call-ai codex "Explain the visitor pattern in Go"
```

**What happens:**
1. Spawns one sub-agent for Codex thorough (gpt-5.2-codex)
2. Runs `ask-ai-runner.sh codex gpt-5.2-codex "..."`
3. Returns single response

### Gemini Only
```
/call-ai gemini "What are the tradeoffs between REST and GraphQL?"
```

### Claude Only (Fresh Context)
```
/call-ai claude "Review this error handling approach: [code]"
```

> **Note:** The `claude` option spawns a fresh Claude sub-agent with no conversation history. Useful for getting an unbiased second opinion.

## With File Input

For large prompts (>4K chars), use a file:

```
/call-ai codex -f ~/.prompts/architecture-review.xml
```

Or via `/second-opinion`:
```
/so codex "Review the authentication flow"
```
This automatically generates the prompt file via `/complete-prompt`.

## Expected Output

```
## CODEX (gpt-5.2-codex) ##
────────────────────────────────────────
[AI response here]
────────────────────────────────────────
📁 Saved: .responses/codex-gpt-5.2-codex-20260205-143022.txt
```

## When to Use Single AI

| Scenario | Recommended |
|----------|-------------|
| Quick factual question | `codex` or `gemini` |
| Code explanation | `codex` (best for code) |
| Architecture discussion | `gemini` (good at tradeoffs) |
| Fresh perspective needed | `claude` (no context bleed) |
| Testing/debugging the skill | Any single AI |
