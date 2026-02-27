# Workflow Details

Detailed step-by-step instructions for executing `/second-opinion`.

## Step 1: Parse Arguments

Extract from user input:
- **AI_SPEC**: First word if it's `codex`, `gemini`, `claude`, or `:all`
- **QUESTION**: Everything else (the user's actual question)

## Step 2: Pre-flight Evaluation

Ask yourself:
- Is the question specific enough for external AIs?
- Does it need codebase context?
- Are there ambiguities to clarify?

If unclear, use AskUserQuestion to clarify.

## Step 3: Build Context Using /complete-prompt

> **CRITICAL**: This step is MANDATORY. External AIs have ZERO context about this conversation.

### 3.1 Select the appropriate mode

| Question Type | Mode | Use Case |
|---------------|------|----------|
| About current codebase | `full` | Complete context for implementation |
| Quick question | `brief` | Minimal context, token-efficient |
| Error/debugging | `debug` | Troubleshooting errors |
| Architecture review | `architect` | Design discussion, no code yet |
| Code review/comparison | `diff` | PR review, comparing changes |
| General programming | `general` | Non-technical catch-all |
| Research/literature | `research` | Fact-finding, literature review |
| Career/job search | `career` | Resume, interview prep |
| Learning/study | `learning` | Study plans, tutoring |

### 3.2 Invoke /complete-prompt

Use the Skill tool to delegate context generation:

```
Skill tool with:
- skill: "complete-prompt"
- args: "{MODE} --refs"
```

The `--refs` flag tells complete-prompt to include file references (paths + key blocks) instead of
full file contents, since the external AIs have codebase access.

Example: `args: "debug --refs"` or `args: "brief --refs"` or `args: "--refs"` (full mode default)

**What happens:**
1. `/complete-prompt` reads its templates
2. Extracts context from this conversation
3. Fills the template with proper XML+CDATA structure
4. Saves to `.prompts/{timestamp}-{mode}.xml`
5. Returns the file path

### 3.3 Capture the output

After `/complete-prompt` completes, you'll have:
- `PROMPT_FILE_PATH`: Path to the saved XML file (e.g., `.prompts/20260204-210532-debug.xml`)

**DO NOT proceed to Step 4 until /complete-prompt has returned a file path.**

## Step 4: Spawn Sonnet Coordinator

Spawn a Sonnet coordinator sub-agent that handles the mechanical orchestration work.

### 4.1 Read the template

```
Read tool: templates/coordinator-prompt.md
```

### 4.2 Fill placeholders

- Replace `{{AI_SPEC}}` with the parsed AI specification
- Replace `{{PROMPT_FILE_PATH}}` with the file path from Step 3

### 4.3 Spawn coordinator

```
Task tool with:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Coordinate AI calls"
- prompt: (filled template content)
```

Wait for the coordinator to return all raw responses.

## Step 5: Verify Responses

Before synthesizing, verify response quality.

### Completeness check
- All expected responses received?
- Expected count: 2 (default), 6 (`:all`), or 1 (single AI)

### Quality check
- Any suspiciously short responses (<100 chars)?
- Any responses contain only error messages?
- Any obvious truncation ("..." at end)?

### Decision

| Result | Action |
|--------|--------|
| All pass | Proceed to synthesis |
| Some fail quality check | Flag issues in synthesis, note incomplete data |
| All fail | Report failures, offer troubleshooting |

> Quality flags are informational — they help calibrate trust in the synthesis but don't block progress.

## Step 6: Synthesize Responses

Apply smart merging rules. See [synthesis-guide.md](synthesis-guide.md) for details.
