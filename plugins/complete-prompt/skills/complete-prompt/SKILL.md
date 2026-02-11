---
name: complete-prompt
description: |
  Generate context prompts for AI-to-AI handoffs. Use when sharing conversation
  context, continuing work in a fresh session, or handing off to another LLM.
  Supports full, brief, debug, architect, diff, general, research, career, and learning modes.
  Use for "cp", "complete prompt", "context prompt", "handoff prompt", "share context", or "hand off to another AI".
version: "1.9"
---

# Complete Prompt

Generate a self-contained prompt capturing current conversation context for seamless AI-to-AI handoff.

## Usage

| Mode | Command | Use Case |
|------|---------|----------|
| **Full** | `/complete-prompt` | Default. Complete context for implementation |
| **Brief** | `/complete-prompt brief` | Quick questions, minimal context |
| **Debug** | `/complete-prompt debug` | Troubleshooting errors, fresh diagnosis |
| **Architect** | `/complete-prompt architect` | Design discussion, no implementation |
| **Diff** | `/complete-prompt diff` | Code review, comparing changes |
| **General** | `/complete-prompt general` | Non-technical catch-all |
| **Research** | `/complete-prompt research` | Literature review, fact-finding |
| **Career** | `/complete-prompt career` | Resume, job search, interview prep |
| **Learning** | `/complete-prompt learning` | Study plans, tutoring, skill acquisition |
| **--refs** | Modifier (any mode) | File paths + key blocks only (receiving AI has codebase access) |

## Roles & Responsibilities

| Role | What They Do |
|------|--------------|
| **You (Main Agent)** | Extract context from conversation, load template, fill ALL sections, output XML |
| **User** | Invoke `/cp [mode]`, copy output, paste into another AI |
| **Receiving AI** | Parse context, continue work, request clarification if needed |

### Key Principle

```
┌─────────────────────────────────────────────────────────────┐
│  Main Agent CREATES the handoff (fully automated)           │
│  User COPIES the output (no manual template filling)        │
│  Receiving AI EXECUTES based on context                     │
└─────────────────────────────────────────────────────────────┘
```

The user should **never** need to fill in template fields manually. Your job is to analyze the conversation history and populate every section automatically.

---

## Agent Workflow (Fully Automated)

**Why no sub-agent?** You (the main agent) have access to conversation history. Sub-agents don't inherit context, so this is pure text generation from context you already have.

### Step 1: Review Conversation

Extract from conversation history:

| Component | What to Extract |
|-----------|-----------------|
| **Project** | Repo name, language, framework |
| **Task** | Current goal, original request |
| **Files** | Files read, modified, discussed |
| **Code** | Key snippets central to task |
| **Decisions** | Choices made, alternatives rejected |
| **Constraints** | Technical limits, user preferences using MoSCoW (Must/Should/Could) |
| **Verification** | How you confirmed the current state (tests, logs, etc.) |
| **Status** | Done, in progress, blocked |
| **Success Criteria** | What "done" looks like |
| **Non-Goals** | What NOT to do (prevents scope creep) |
| **Assumptions** | Implicit knowledge that could be wrong |
| **User Preferences** | Coding style, verbosity, conventions |

### Pre-Flight Checklist

Before generating, verify:

1. **Source of Truth:** Do you have actual file content? (Don't summarize code unless Mode=Brief)
2. **Specificity:** Are error messages verbatim? Are file paths absolute?
3. **Completeness:** Are success criteria measurable? Are assumptions stated?
4. **Security:** Have you scrubbed API keys/secrets? (NEVER include secrets)
5. **Verification:** Have you explicitly stated how you verified your current status?

**Mode-specific behavior:**
- `brief`: Skip checklist unless ambiguity detected
- `full`/`architect`/`debug`: Apply full checklist
- `diff`: Verify git context (branch, commits, file paths)
- `general`: Skip file/code extraction. Focus on goals, key points, and open questions.
- `research`/`career`/`learning`: Apply full checklist. Focus on domain-specific sections.

If any check fails, ask for missing context before generating.

### File Content Strategy

The `--refs` modifier controls how the `<files>` section is populated. It combines with any mode:
`/cp --refs`, `/cp debug --refs`, `/cp brief --refs`, etc.

**Default (no flag)** — Full file contents in CDATA:
- Include complete file contents
- Current behavior, no changes

**With `--refs`** — Reference-only:
- Add `mode="reference"` attribute to the `<files>` element
- Add a `<note>` telling the receiving AI it has codebase access
- For each file: include `path` and `purpose` (same as before)
- Replace CDATA file content with `<key-blocks>` listing:
  - Symbol names (functions, classes) central to the task
  - Line ranges for critical sections
  - Brief description of each block's relevance
- For diff mode `<changes>`: include change summary + rationale, omit before/after CDATA

Example (`--refs`):
```xml
<files mode="reference">
  <note>You have access to the codebase — read files directly as needed.</note>
  <file path="src/routes/users.ts" purpose="Endpoint being modified">
    <key-blocks>
      <block location="lines 12-18" description="GET /users handler — needs pagination params" />
    </key-blocks>
  </file>
</files>
```

Example diff mode (`--refs`):
```xml
<changes mode="reference">
  <note>You have codebase access. Run `git diff` or read files directly for full changes.</note>
  <file path="src/utils/PaginationHelper.ts">
    <summary>Changed Math.floor to Math.ceil in getTotalPages()</summary>
    <rationale>Math.floor truncates partial pages, making last page unreachable</rationale>
  </file>
</changes>
```

**When to use `--refs`:**
- Receiving AI runs in the same working directory (e.g., via `/second-opinion` → `/call-ai`)
- Codex CLI, Gemini CLI, Claude CLI can all read files

**Do NOT use `--refs` when:**
- Copying prompt to a web UI (ChatGPT, Claude.ai, Gemini web)
- Receiving AI has no filesystem access

### Step 2: Load Template

Based on the mode selected (default: `full`), read the corresponding template:

```
templates/{mode}.xml
```

Available templates:
- `templates/full.xml` — Complete context (default)
- `templates/brief.xml` — Minimal context
- `templates/debug.xml` — Error-focused
- `templates/architect.xml` — Design discussion
- `templates/diff.xml` — Code review
- `templates/general.xml` — Non-technical catch-all
- `templates/research.xml` — Research and fact-finding
- `templates/career.xml` — Career and job search
- `templates/learning.xml` — Learning and study plans

**Important:** Use the `Read` tool to load the template. Do not hallucinate the XML structure.
**Tip:** If you need to read multiple files (templates + source code), use parallel `Read` calls to save time.

### Step 3: Generate Handoff Document

Fill in the template with extracted context. Use CDATA for all code blocks.

---

## Strategic Information Placement

Leverage primacy and recency bias in LLM attention:

```
┌─────────────────────────────────────┐
│  TOP (PRIMACY - High Attention)     │
│  • Summary (TL;DR)                  │
│  • System Role                      │
│  • Success Criteria                 │
├─────────────────────────────────────┤
│  MIDDLE (Context - Reference)       │
│  • Files                            │
│  • Decisions                        │
│  • Constraints                      │
│  • Assumptions                      │
├─────────────────────────────────────┤
│  BOTTOM (RECENCY - High Attention)  │
│  • Current Status                   │
│  • Verification                     │
│  • Next Steps                       │
│  • Task Instruction                 │
└─────────────────────────────────────┘
```

---

## Examples by Mode

Modes with dedicated example files are referenced below. Modes without dedicated files have inline examples.

| Mode | Example Source |
|------|---------------|
| Full | `examples/full.md` (3 examples) |
| Brief | `examples/brief.md` (3 examples) |
| Debug | `examples/debug.md` (3 examples) |
| Architect | `examples/architect.md` (3 examples) |
| Diff | `examples/diff.md` (3 examples) |
| Refs | Inline below |
| General | Inline below |
| Research | Inline below |
| Career | Inline below |
| Learning | Inline below |

Read `examples/{mode}.md` when you need additional reference for that mode's XML structure.

### Refs Mode (any mode + `--refs`)

Reference-only output for when the receiving AI has codebase access:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="brief">
<meta>
<generated-at>2026-02-04 20:45:32</generated-at>
<source>Claude Code /cp</source>
</meta>

<summary>Adding pagination to user list API endpoint.</summary>

<system-role>
Continue this task directly with minimal ceremony. Be concise and action-oriented. Ask only if blocking.
</system-role>

<task>Implement offset/limit pagination for GET /api/users</task>

<files mode="reference">
<note>You have access to the codebase — read files directly as needed.</note>
<file path="src/routes/users.ts" purpose="Current endpoint without pagination">
  <key-blocks>
    <block location="lines 14-19" description="GET /users handler — returns all users, needs pagination params" />
  </key-blocks>
</file>
<file path="src/utils/PaginationHelper.ts" purpose="Existing pagination utility">
  <key-blocks>
    <block location="lines 1-8" description="getTotalPages() — may need offset/limit support" />
  </key-blocks>
</file>
</files>

<status>Endpoint exists, need to add query params and DB limit.</status>

<next-steps>Add offset/limit query params, update DB query, add total count header.</next-steps>

<what-is-missing>List what you need if context is insufficient.</what-is-missing>

</context-handoff>
```

### General Mode

Non-technical catch-all when specific modes don't apply:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="general">
<meta>
<generated-at>2026-02-04 20:45:32</generated-at>
<source>Claude Code /cp</source>
</meta>

<summary>Researching Quantum Key Distribution (QKD) basics for a blog post.</summary>

<system-role>
You are an intelligent assistant continuing a session. Your goal is to provide continuity by understanding what has already been discussed, researching, or decided.
</system-role>

<goal>Understand the BB84 protocol and its security guarantees.</goal>

<key-points>
<point>QKD uses quantum mechanics to distribute encryption keys securely.</point>
<point>BB84 protocol relies on the no-cloning theorem.</point>
<point>Eve cannot intercept the key without disturbing the quantum state.</point>
</key-points>

<open-questions>
<question>What are the practical distance limits of fiber-optic QKD?</question>
<question>How does QKD compare to Post-Quantum Cryptography (PQC)?</question>
</open-questions>

<next-steps>Find recent real-world implementations of QKD networks.</next-steps>

</context-handoff>
```

### Research Mode

Literature review and fact-finding context:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="research">
<meta>
<generated-at>2026-02-05 10:30:00</generated-at>
<source>Claude Code /cp</source>
</meta>

<summary>Investigating best practices for AI-assisted code review.</summary>

<system-role>
You are a research assistant continuing an investigation. Synthesize sources critically, identify gaps, and suggest next research directions. Cite sources when making claims.
</system-role>

<research-topic>
<subject>AI-assisted code review tools and practices</subject>
<scope>2022-2026, enterprise software teams</scope>
<motivation>Evaluating whether to adopt AI code review for our team</motivation>
</research-topic>

<research-questions>
<question type="primary">How effective are AI code review tools at catching bugs vs human reviewers?</question>
<question type="secondary">What are the common false positive rates?</question>
</research-questions>

<findings>
<finding confidence="high">
<claim>AI reviewers catch ~30% of bugs missed by human reviewers</claim>
<evidence>Meta-analysis of 12 studies showed complementary detection patterns</evidence>
<source>ACM Computing Surveys, 2025</source>
</finding>
</findings>

<knowledge-gaps>
<gap>Long-term impact on developer skills when relying on AI review</gap>
</knowledge-gaps>

<next-steps>Find case studies from companies of similar size (100-500 engineers).</next-steps>

</context-handoff>
```

### Career Mode

Resume and job search context:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="career">
<meta>
<generated-at>2026-02-05 10:30:00</generated-at>
<source>Claude Code /cp</source>
</meta>

<summary>Senior engineer transitioning from backend to ML engineering roles.</summary>

<system-role>
You are a career coach continuing a session. Provide actionable advice tailored to the candidate's profile and target roles. Be specific about resume improvements, interview strategies, and positioning.
</system-role>

<career-goal>
<objective>Transition from backend engineering to ML engineering</objective>
<timeline>3-6 months</timeline>
<constraints>Remote-friendly, US-based companies</constraints>
</career-goal>

<candidate-profile>
<experience>8 years backend (Python, Go), 2 years ML hobby projects</experience>
<strengths>System design, data pipelines, production reliability</strengths>
<development-areas>ML theory, deep learning frameworks</development-areas>
<unique-value>Bridge between ML research and production systems</unique-value>
</candidate-profile>

<target-roles>
<role>
<title>ML Engineer</title>
<company>Series B+ startups</company>
<requirements>Python, PyTorch/TensorFlow, ML pipelines</requirements>
<fit-analysis>Strong on systems, need to emphasize ML project work</fit-analysis>
</role>
</target-roles>

<current-stage>
<completed>Resume draft v1, LinkedIn updated</completed>
<in-progress>Building portfolio project (recommendation system)</in-progress>
</current-stage>

<next-steps>Review resume for ML-focused positioning.</next-steps>

</context-handoff>
```

### Learning Mode

Study plans and skill acquisition context:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="learning">
<meta>
<generated-at>2026-02-05 10:30:00</generated-at>
<source>Claude Code /cp</source>
</meta>

<summary>Learning Rust for systems programming, currently on ownership/borrowing.</summary>

<system-role>
You are a tutor/learning coach continuing a session. Adapt explanations to the learner's level. Use examples, analogies, and practice problems. Identify misconceptions and build on existing knowledge.
</system-role>

<learning-goal>
<subject>Rust programming language</subject>
<objective>Build a CLI tool and contribute to an open source project</objective>
<motivation>Career growth in systems programming</motivation>
<timeline>3 months, 10 hours/week</timeline>
</learning-goal>

<learner-profile>
<current-level>Intermediate</current-level>
<background>5 years Python, 2 years Go</background>
<learning-style>Example-driven, prefers hands-on coding</learning-style>
<time-available>10 hours/week</time-available>
</learner-profile>

<mastery-state>
<concepts-mastered>
<concept>Basic syntax, structs, enums, pattern matching</concept>
</concepts-mastered>
<concepts-in-progress>
<concept>Ownership, borrowing, lifetimes</concept>
</concepts-in-progress>
<struggling-with>
<concept>Lifetime annotations in function signatures</concept>
</struggling-with>
</mastery-state>

<curriculum>
<phase order="2" status="in-progress">
<topic>Memory management and ownership</topic>
<resources>Rust Book chapters 4-10, Rustlings exercises</resources>
<practice>Implement a linked list with proper ownership</practice>
</phase>
</curriculum>

<next-steps>Work through lifetime examples with increasing complexity.</next-steps>

</context-handoff>
```

---

## Step 4: Output

Save the handoff to a file:

1. Generate filename: `{YYYYMMDD}-{HHMMSS}-{mode}.xml`
   - Example: `20260204-204532-debug.xml`

2. Write XML to: `.prompts/{filename}` (relative to this skill's directory)

3. Confirm with brief message:

```
✅ Saved: .prompts/20260204-204532-debug.xml

Copy to clipboard:  cat .prompts/20260204-204532-debug.xml | pbcopy  (macOS) or xclip -sel c (Linux)
```

4. **Validate** (recommended):
   ```bash
   ./validate.sh .prompts/{filename}
   ```
   If validation fails, fix and regenerate before showing to user.

**Note:** The `.prompts/` directory stores all handoffs for reference. Files are gitignored.

---

## Guidelines

### Mode Selection Guide

| Situation | Recommended Mode |
|-----------|------------------|
| Continuing implementation work | **Full** (default) |
| Quick question, limited tokens | **Brief** |
| Error or bug to diagnose | **Debug** |
| Design review, no code yet | **Architect** |
| PR review, comparing changes | **Diff** |
| Non-technical catch-all | **General** |
| Researching a topic | **Research** |
| Job search or resume help | **Career** |
| Studying or learning a skill | **Learning** |

### Token Budget Guidelines

| Mode | Target | Max | Use Case |
|------|--------|-----|----------|
| **brief** | 500 | 1K | Quick question, single file context |
| **full** | 2K | 5K | Standard handoff, multiple files |
| **debug** | 1.2K | 3K | Error + stack trace + relevant code |
| **architect** | 1.5K | 4K | Design discussion, requirements |
| **diff** | 1K | 2.5K | Code changes + surrounding context |
| **general** | 1K | 3K | Non-technical catch-all |
| **research** | 1.5K | 3K | Research findings, sources, methodology |
| **career** | 1.5K | 3K | Resume content, job targets, strategy |
| **learning** | 1.5K | 3K | Learning goals, curriculum, progress |

**Scaling by context window:**
- 8K window: Halve the Max values
- 128K window: Can double Max, but keep Target to maintain clarity

**Note:** Target is ideal size. Prioritize signal over completeness.

### What to Include

- **Be thorough**: Receiving agent has ZERO prior context
- **Full code context**: Include entire files when relevant, not just snippets
- **Show relationships**: If file A calls file B, include both
- **Note decisions**: Especially rejected alternatives (prevents rehashing)
- **Be specific**: File paths, function names, exact error messages
- **Use CDATA**: Always wrap code in `<![CDATA[...]]>` to prevent XML parsing issues
- **--refs mode**: Include enough in `<key-blocks>` that the receiving AI knows WHERE to look,
  but let it read the actual content itself. Think "table of contents" for relevant code.

### What NOT to Include

- Trivial conversation back-and-forth
- Obvious context (receiving agent knows programming)
- Sensitive data (API keys, passwords, personal info)

### Why XML + CDATA?

Research and testing show that XML is preferred for Claude due to:
- **Precision:** Explicit tags create clear boundaries for instructions.
- **Reliability:** Less prone to misinterpretation than Markdown headers in complex prompts.
- **Safety:** CDATA prevents parsing issues when the code contains backticks, `#`, or other Markdown-sensitive characters.
- **Security:** Easier to delineate content blocks and prevent prompt injection "escaping".

Markdown code blocks break when the code itself contains:
- Triple backticks (common in documentation)
- `#` at line start (interpreted as headers)
- Other markdown syntax

XML with CDATA escapes everything cleanly:
```xml
<file path="example.md">
<![CDATA[
# This heading won't break parsing
```python
def example():
    """Even nested code blocks work"""
    pass
```
]]>
</file>
```
