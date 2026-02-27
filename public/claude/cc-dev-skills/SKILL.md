---
name: cc-dev-skills
description: Guide for creating effective skills. Use for "create a skill", "new skill", "write a SKILL.md", "update a skill", "skill template", or extending Claude's capabilities with specialized workflows and tools.
---

# Skill Creator

This skill provides guidance for creating effective skills.

## About Skills

Skills are modular, self-contained packages that extend Claude's capabilities by providing specialized knowledge, workflows, and tools. They transform Claude from a general-purpose agent into a specialized agent equipped with procedural knowledge that no model can fully possess.

### What Skills Provide

1. Specialized workflows - Multi-step procedures for specific domains
2. Tool integrations - Instructions for working with specific file formats or APIs
3. Domain expertise - Company-specific knowledge, schemas, business logic
4. Bundled resources - Scripts, references, and assets for complex and repetitive tasks

### Agent Skills Open Standard

Claude Code skills follow the [Agent Skills](https://agentskills.io) open standard, which works across multiple AI tools. Claude Code extends the standard with additional features like invocation control, subagent execution, and dynamic context injection.

## Core Principles

### Concise is Key

The context window is a public good. Skills share it with system prompts, conversation history, other skills' metadata, and the actual user request.

**Default assumption: Claude is already very smart.** Only add context Claude doesn't already have. Challenge each piece of information: "Does Claude really need this?" and "Does this paragraph justify its token cost?"

Prefer concise examples over verbose explanations.

### Set Appropriate Degrees of Freedom

Match specificity to the task's fragility and variability:

**High freedom (text-based instructions)**: Multiple approaches valid, decisions depend on context.

**Medium freedom (pseudocode or scripts with parameters)**: Preferred pattern exists, some variation acceptable.

**Low freedom (specific scripts, few parameters)**: Operations fragile, consistency critical, specific sequence required.

Think of Claude exploring a path: a narrow bridge needs guardrails (low freedom), while an open field allows many routes (high freedom).

## Anatomy of a Skill

### Directory Structure

```
skill-name/
├── SKILL.md              (required — main instructions)
├── scripts/              (optional — executable code)
├── references/           (optional — documentation loaded into context as needed)
└── assets/               (optional — files used in output, not loaded into context)
```

### Skill Storage Locations

Where a skill is stored determines its scope:

| Location | Path | Applies to |
|----------|------|------------|
| Enterprise | Managed settings | All users in organization |
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where plugin is enabled |

Priority when names conflict: **enterprise > personal > project**. Plugin skills use `plugin-name:skill-name` namespace so cannot conflict.

**Note:** Claude Code also discovers skills from nested `.claude/skills/` directories in subdirectories (monorepo support) and from `--add-dir` directories.

**Budget:** Skill descriptions share a 2% context window budget (fallback: 16k chars). Configurable via `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var — useful when many skills are installed.

### SKILL.md

Every SKILL.md consists of:

- **Frontmatter** (YAML): Metadata that controls triggering, invocation, and execution behavior
- **Body** (Markdown): Instructions loaded AFTER the skill triggers

#### Frontmatter Reference

All fields are optional. Only `description` is recommended.

| Field | Description |
|-------|-------------|
| `name` | Display name (kebab-case, max 64 chars). If omitted, uses directory name. |
| `description` | What the skill does and when to use it. Claude uses this to decide when to apply the skill. If omitted, uses first paragraph of body. |
| `argument-hint` | Hint shown during autocomplete (e.g., `[issue-number]`, `[filename] [format]`). |
| `disable-model-invocation` | Set `true` to prevent Claude from auto-loading. User must invoke with `/name`. |
| `user-invocable` | Set `false` to hide from `/` menu. Use for background knowledge. |
| `allowed-tools` | Tools Claude can use without permission when this skill is active. |
| `model` | Model to use when this skill is active. |
| `context` | Set to `fork` to run in a forked subagent context. |
| `agent` | Subagent type when `context: fork` is set (e.g., `Explore`, `Plan`, custom agent). |
| `hooks` | Hooks scoped to this skill's lifecycle. |

#### String Substitutions

Skills support dynamic values in the body:

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill. If not present in content, arguments are appended as `ARGUMENTS: <value>`. |
| `$ARGUMENTS[N]` | Specific argument by 0-based index (e.g., `$ARGUMENTS[0]`). |
| `$N` | Shorthand for `$ARGUMENTS[N]` (e.g., `$0`, `$1`). |
| `${CLAUDE_SESSION_ID}` | Current session ID. Useful for logging or session-specific files. |

Example:
```yaml
---
name: session-logger
description: Log activity for this session
---
Log the following to logs/${CLAUDE_SESSION_ID}.log:
$ARGUMENTS
```

#### Dynamic Context Injection

The BANG-BACKTICK syntax (exclamation mark immediately followed by a backtick-wrapped command) runs shell commands **before** skill content is sent to Claude. Output replaces the placeholder -- Claude sees actual data, not the command.

Example skill using dynamic context (BANG-BACKTICK patterns replaced with DYNAMIC() to avoid parser execution):

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---
## Pull request context
- PR diff: DYNAMIC(gh pr diff)
- PR comments: DYNAMIC(gh pr view --comments)

## Your task
Summarize this pull request...
```

#### Invocation Control

Three invocation modes with different visibility and control:

| Frontmatter | User can invoke | Claude can invoke | Context behavior |
|-------------|----------------|-------------------|-----------------|
| *(default)* | Yes | Yes | Description always in context |
| `disable-model-invocation: true` | Yes | No | Description NOT in context |
| `user-invocable: false` | No | Yes | Description always in context |

**Decision matrix:**
- **Reference knowledge** (conventions, style guides) → default (Claude auto-applies)
- **Explicit actions** (deploy, release) → `disable-model-invocation: true`
- **Background knowledge** (internal only) → `user-invocable: false`

#### Subagent Execution

Add `context: fork` to run a skill in isolation. The skill body becomes the subagent's prompt — it won't have access to conversation history.

```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---
Research $ARGUMENTS thoroughly:
1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

The `agent` field determines execution environment. Options: `Explore`, `Plan`, `general-purpose`, or any custom agent from `.claude/agents/`. If omitted, uses `general-purpose`.

**Important:** `context: fork` only makes sense for skills with explicit task instructions. Guidelines-only skills (e.g., "use these conventions") return without meaningful output because the subagent receives guidelines but no actionable prompt.

### Bundled Resources

#### Scripts (`scripts/`)

Executable code for tasks that require deterministic reliability or are repeatedly rewritten.

- **When to include**: Same code rewritten repeatedly or deterministic reliability needed
- **Benefits**: Token efficient, deterministic, may execute without loading into context
- **Note**: Scripts may still be read by Claude for patching or environment-specific adjustments

#### References (`references/`)

Documentation loaded into context as needed to inform Claude's process.

- **When to include**: Detailed documentation Claude should reference while working
- **Use cases**: Database schemas, API docs, domain knowledge, policies, workflow guides
- **Best practice**: If files are large (>10k words), include grep patterns in SKILL.md
- **Avoid duplication**: Information lives in either SKILL.md or references, not both. Keep SKILL.md lean; move detailed material to references.

#### Assets (`assets/`)

Files used in output, not loaded into context.

- **When to include**: Files needed in the final output (templates, images, boilerplate)
- **Examples**: Logo files, PowerPoint templates, HTML/React boilerplate, fonts

### What NOT to Include

Do NOT create extraneous files: README.md, INSTALLATION_GUIDE.md, CHANGELOG.md, etc. A skill contains only what an AI agent needs to do the job — no auxiliary documentation about the creation process.

## Progressive Disclosure

Skills use a three-level loading system:

1. **Metadata (description)** — Always in context (~100 words)
2. **SKILL.md body** — When skill triggers (<5k words)
3. **Bundled resources** — As needed by Claude (unlimited — scripts can execute without loading)

Keep SKILL.md body under 500 lines. Split content into separate files when approaching this limit. Reference split-out files from SKILL.md with clear "when to read" guidance.

**Key principle:** When a skill supports multiple variations, keep only the core workflow and selection guidance in SKILL.md. Move variant-specific details into separate reference files.

**Pattern 1: High-level guide with references**
```markdown
## Advanced features
- **Form filling**: See [FORMS.md](FORMS.md) for complete guide
- **API reference**: See [REFERENCE.md](REFERENCE.md) for all methods
```
Claude loads reference files only when needed.

**Pattern 2: Domain-specific organization**
```
bigquery-skill/
├── SKILL.md (overview and navigation)
└── references/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    └── product.md (API usage, features)
```
When a user asks about sales metrics, Claude only reads `sales.md`.

**Pattern 3: Conditional details**
```markdown
For simple edits, modify the XML directly.
**For tracked changes**: See [REDLINING.md](REDLINING.md)
```
Claude reads detailed references only when the user needs those features.

**Important:** Avoid deeply nested references — keep one level deep from SKILL.md. For reference files longer than 100 lines, include a table of contents at the top.

## Skill Creation Process

1. Research existing skills for inspiration
2. Understand the skill with concrete examples
3. Plan reusable skill contents (scripts, references, assets)
4. Initialize the skill (run init_skill.py)
5. Edit the skill (implement resources and write SKILL.md)
6. Package the skill (run package_skill.py)
7. Iterate based on real usage

Follow these steps in order, skipping only when clearly not applicable.

### Step 0: Research Existing Skills

Before creating a new skill, check if existing skills solve a similar problem or provide useful patterns.

**Search the skills registry:**
```bash
npx skills search <keyword>
```

Browse [skills.sh](https://skills.sh) for community-published skills. Even if no existing skill fits exactly, studying similar skills provides:
- Proven structural patterns
- Description phrasing that triggers well
- Ideas for bundled resources

**Check local skills:**
```bash
ls ~/.claude/skills/ .claude/skills/ 2>/dev/null
```

Skip this step only when building something clearly novel with no analogous precedent.

### Step 1: Understanding the Skill with Concrete Examples

Skip this step only when usage patterns are already clearly understood.

To create an effective skill, clearly understand concrete examples of how it will be used. Ask targeted questions:

- "What functionality should the skill support?"
- "Can you give examples of how this skill would be used?"
- "What would a user say that should trigger this skill?"

Avoid overwhelming users — start with the most important questions and follow up as needed.

### Step 2: Planning the Reusable Skill Contents

Turn concrete examples into an effective skill by analyzing each example:

1. How to execute on the example from scratch
2. What scripts, references, and assets would help when executing repeatedly

Examples:
- "Help me rotate this PDF" → `scripts/rotate_pdf.py` (same code each time)
- "Build me a todo app" → `assets/hello-world/` template (same boilerplate each time)
- "How many users logged in today?" → `references/schema.md` (re-discovers schemas each time)

### Step 3: Initializing the Skill

Skip if iterating on an existing skill.

Always run `init_skill.py` for new skills:

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

The script creates the skill directory with a SKILL.md template and example resource directories.

**Prerequisite**: The validation and packaging scripts require PyYAML (`pip install pyyaml`).

### Step 4: Edit the Skill

When editing, remember the skill is for another Claude instance. Include non-obvious procedural knowledge and domain-specific details.

#### Consult Design References

- **Workflow patterns**: See [references/workflows.md](references/workflows.md) — sequential, conditional, router, lifecycle, and checklist patterns
- **Best practices**: See [references/best-practices.md](references/best-practices.md) — description writing, prompt engineering, output patterns, anti-patterns, testing, and quality checklist

#### Start with Reusable Skill Contents

Begin with the resources identified in Step 2. This may require user input (e.g., brand assets, documentation).

Test added scripts by running them. If many similar scripts, test a representative sample.

Delete unused example files and directories from initialization.

#### Update SKILL.md

**Writing Guidelines:** Use imperative/infinitive form throughout.

**Frontmatter:**
- `description` is the primary triggering mechanism. Include both what the skill does AND specific trigger phrases.
- Include all "when to use" information in the description — NOT in the body. The body loads only after triggering, so "When to Use" sections in the body do not help.
- Example: `"Comprehensive document processing. Use for 'create docx', 'edit document', 'tracked changes', or any .docx task."`

**Body:** Write focused instructions for using the skill and its bundled resources. See [references/best-practices.md](references/best-practices.md) for prompt engineering and quality guidance.

### Step 5: Packaging a Skill

Package into a distributable `.skill` file:

```bash
scripts/package_skill.py <path/to/skill-folder>
```

Optional output directory:
```bash
scripts/package_skill.py <path/to/skill-folder> ./dist
```

The script validates first (frontmatter, naming, description, structure), then packages. Fix validation errors and re-run if it fails.

### Step 6: Iterate

After testing with real tasks, iterate on the skill:

1. Use the skill on real tasks
2. Notice struggles or inefficiencies
3. Identify how SKILL.md or bundled resources should be updated
4. Implement changes and test again

See the "Testing & Iteration" section in [references/best-practices.md](references/best-practices.md) for structured evaluation methods.
