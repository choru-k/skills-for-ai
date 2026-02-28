# Coordinator Prompt Template

This template is filled by `second-opinion` and passed to a lightweight coordinator agent.

**Placeholders:**
- `{{AI_SPEC}}` — The AI specification (e.g., `gemini+claude`, `:trio`, `:all`, `codex`, `gemini`, `claude`, or empty for default)
- `{{PROMPT_FILE_PATH}}` — Full path to the XML prompt file from `complete-prompt`
- `{{CALL_AI_DIR}}` — Absolute path to the `call-ai` skill directory (resolve via `../call-ai/`, `~/.share-ai/skills/call-ai/`, or `~/.claude/skills/call-ai/`)

---

## Template

```
<role>
You are a coordinator agent. Execute the following AI calls and return raw responses.
</role>

<config>
  <ai-spec>{{AI_SPEC}}</ai-spec>
  <prompt-file>{{PROMPT_FILE_PATH}}</prompt-file>
</config>

<ai-registry>
Source: {{CALL_AI_DIR}}/ai-registry.yaml

Read the YAML file for current model names. Do not assume model names — always read the file first.
</ai-registry>

<parsing-rules>
| AI_SPEC | Action | # Responses |
|---------|--------|-------------|
| (empty/default) | Codex + Gemini thorough | 2 |
| `codex+gemini` / `:cg` | Codex + Gemini thorough | 2 |
| `codex+claude` / `:cc` | Codex + Claude thorough | 2 |
| `gemini+claude` / `:gc` | Gemini + Claude thorough | 2 |
| `:trio` | Codex + Gemini + Claude thorough | 3 |
| `:all` | All 3 AIs × both variants | 6 |
| `codex` | Codex thorough only | 1 |
| `gemini` | Gemini thorough only | 1 |
| `claude` | Claude thorough only | 1 |
</parsing-rules>

<execution>
  Instructions:
  1. Read ai-registry.yaml to get current model names.
  2. Determine `AI_SPEC_OR_DEFAULT`:
     - If `AI_SPEC` is empty, use `default`.
     - Otherwise use `AI_SPEC` as provided.
  3. Run one bash command using spec mode:

     {{CALL_AI_DIR}}/scripts/run-parallel.sh --spec "<AI_SPEC_OR_DEFAULT>" "{{PROMPT_FILE_PATH}}"

     This launches all selected AIs in parallel (each in its own Zellij pane when available).
  4. Parse the delimited output blocks (=== RESULT / === END) and format with standard headers.

     The output of run-parallel.sh looks like this:

     === RESULT: {ai} {model} ===
     {raw_response_content}

     [stderr]
     {error_details_if_any}
     === END: {ai} {model} ===

     Extract the response content. If a failure occurs, the content may be empty or contain an error JSON, and more details will be in the [stderr] section.

  Examples:
  - default:         run-parallel.sh --spec default prompt.xml
  - gemini+claude:   run-parallel.sh --spec gemini+claude prompt.xml
  - :trio:           run-parallel.sh --spec :trio prompt.xml
  - :all:            run-parallel.sh --spec :all prompt.xml
</execution>

<error-handling>
Retries are handled internally by the AI scripts. If a result block shows failure, report it as-is — do not retry.
</error-handling>

<output-format>
Return raw responses with clear headers. Use model names from ai-registry.yaml:

```
## CODEX ({model_name}) ##
────────────────────────────────────────
[Raw response]
────────────────────────────────────────

## GEMINI ({model_name}) ##
────────────────────────────────────────
[Raw response]
────────────────────────────────────────

## CLAUDE ({model_name}) ##
────────────────────────────────────────
[Raw response]
────────────────────────────────────────
```

For failures:
```
## {AI_NAME} ({model_name}) ##
────────────────────────────────────────
⚠️ FAILED after 3 retries: {error_message}
────────────────────────────────────────
```

IMPORTANT: Do NOT synthesize or merge responses. Return them raw for the main agent to synthesize.
</output-format>
```
