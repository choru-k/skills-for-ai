# skills-for-ai

Custom AI-agent skills with dual distribution support:
- Claude marketplace (`.claude-plugin/marketplace.json`)
- Pi package metadata (`package.json#pi`)

## Canonical lane-root layout (vNext)

```text
public/
  common/
  claude/
  pi/
private/
  common/
  claude/
  pi/
```

Important:
- `private/*` in this **public** repository is lane semantics, not security.
- Secret material must stay outside this repo.
- Public distribution artifacts are generated from discovered `public/*` lane-root paths only.

## Distribution metadata

- `.claude-plugin/marketplace.json` (Claude plugin marketplace)
- `package.json#pi` (`pi.skills`, `pi.extensions`)

## Installation

### Claude marketplace

```bash
claude plugin marketplace add choru-k/skills-for-ai
claude plugin install call-ai
claude plugin install complete-prompt
claude plugin install context-fork
claude plugin install second-opinion
claude plugin install cc-front-compaction
claude plugin install skill-playbook
claude plugin install clarify
claude plugin install cc-dev-skills
claude plugin install cc-dev-agents
claude plugin install cc-dev-hooks
```

### Claude manual

```bash
git clone https://github.com/choru-k/skills-for-ai.git /tmp/skills-for-ai

cp -r /tmp/skills-for-ai/public/common/call-ai ~/.claude/skills/call-ai
cp -r /tmp/skills-for-ai/public/common/complete-prompt ~/.claude/skills/complete-prompt
cp -r /tmp/skills-for-ai/public/claude/cc-context-fork ~/.claude/skills/cc-context-fork
cp -r /tmp/skills-for-ai/public/common/second-opinion ~/.claude/skills/second-opinion
cp -r /tmp/skills-for-ai/public/claude/cc-front-compaction ~/.claude/skills/cc-front-compaction
```

### Pi

```bash
pi install git:github.com/choru-k/skills-for-ai
# or
pi install npm:@choru-k/skills-for-ai
```

## Commands

```bash
just catalog-sync
just catalog-check
just legacy-bridge-check
just drift-check
just private-leak-check
just contract-scenario-check
just pi-pack-dry-run
bash public/common/skill-playbook/scripts/graph-qa.sh
```
