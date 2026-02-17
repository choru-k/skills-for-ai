# cc-dev-skills

A Claude Code skill that guides you through creating effective skills — from SKILL.md frontmatter to workflow design, reference docs, and Python helper scripts. Use it to bootstrap new skills or improve existing ones.

## Usage

Invoke when creating or improving skills:

```
/cc-dev-skills
"Create a new skill for managing Docker containers"
"Update my skill's SKILL.md frontmatter"
"Add a reference doc to my skill"
```

## What It Covers

- **SKILL.md structure** — frontmatter fields, workflow sections, reference linking
- **Skill design patterns** — when to use skills vs hooks vs subagents
- **Python helper scripts** — bundled scripts for skill validation and scaffolding
- **Best practices** — trigger descriptions, tool allowlists, user-invocable config
- **Examples** — Real-world skill patterns

## Included Scripts

| Script | Purpose |
|--------|---------|
| `scripts/validate_skill.py` | Validate SKILL.md frontmatter and structure |
| `scripts/scaffold_skill.py` | Generate skill directory with templates |

## Installation

### Via plugin marketplace (recommended)

```bash
claude plugin marketplace add choru-k/skills-for-ai
claude plugin install cc-dev-skills
```

### Manual

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai
cp -r /tmp/skills-for-ai/plugins/cc-dev-skills/skills/cc-dev-skills ~/.claude/skills/cc-dev-skills
```

## License

[MIT](LICENSE.txt)
