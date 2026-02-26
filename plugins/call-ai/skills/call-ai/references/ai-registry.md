# AI Registry

Shared reference for AI models used by `/call-ai` and `/second-opinion`.

> **📋 Single Source of Truth:** `../ai-registry.yaml`
>
> When updating models, edit the YAML file. This markdown is a human-readable view.

## Available Models

| AI | Thorough Model | Fast Model | CLI |
|----|----------------|------------|-----|
| `codex` | gpt-5.3-codex | gpt-5.2-codex | `codex` |
| `gemini` | gemini-3-pro-preview | gemini-3-flash-preview | `gemini` |
| `claude` | sonnet | haiku | `claude` |

## Parsing Rules

| Input | Action | # Responses |
|-------|--------|-------------|
| (none) | Codex + Gemini thorough | 2 |
| `:all` | All 3 AIs × both variants | 6 |
| `codex` | Codex thorough only | 1 |
| `gemini` | Gemini thorough only | 1 |
| `claude` | Claude thorough only | 1 |

## Execution

All providers now use the unified runner wrapper:

```bash
./ask-ai-runner.sh {AI_NAME} {MODEL_NAME} -f "{PROMPT_FILE_PATH}"
```

## Response Storage

All responses saved to: `.responses/`

| File | Purpose |
|------|---------|
| `{ai}-{model}-{timestamp}.txt` | Raw response |
| `{ai}-{model}-{timestamp}.prompt.txt` | Input prompt |
| `{ai}-{model}-{timestamp}.txt.metrics.json` | Timing/retry metrics |
| `metrics.csv` | Aggregate metrics log |

## Updating Models

When AI providers release new models:

1. Edit `ai-registry.yaml` (single source of truth)
2. Update this file's table to match (human-readable view)
3. Test with: `./ask-ai-runner.sh codex gpt-5.3-codex "test"`
