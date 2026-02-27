# Claude Skill Test Cases

Case files are JSON documents consumed by:

- `scripts/claude-skill-e2e/test-claude-skills.sh`
- `scripts/claude-skill-e2e/claude-skill-harness.py case`

Recommended placement for reusable tests:
- public common skills: `public/common/<skill-name>/tests/claude/*.json`
- public Claude-only skills: `public/claude/<skill-name>/tests/claude/*.json`
- private lane (optional): `private/common/<skill-name>/tests/claude/*.json`, `private/claude/<skill-name>/tests/claude/*.json`

Use `--skill <skill-name>` to run all colocated tests for one skill.

## Quick start

1. Copy `example.simple.example.json` to `my-case.json`
2. Edit prompt/assertions
3. Run:

```bash
bash scripts/claude-skill-e2e/test-claude-skills.sh --case scripts/claude-skill-e2e/cases/my-case.json
```

## Single-turn schema

```json
{
  "name": "my-skill-smoke",
  "model": "sonnet",
  "permission_mode": "bypassPermissions",
  "timeout_seconds": 180,
  "cwd": ".",
  "prompt": "/my-skill do something",
  "append_args": ["--disable-slash-commands"],
  "assertions": {
    "exit_code": 0,
    "assistant_contains": ["expected text"],
    "assistant_not_contains": ["unexpected text"],
    "stdout_contains": ["stream marker"],
    "stderr_not_contains": ["error"],
    "assistant_min_chars": 20
  }
}
```

## Multi-turn E2E schema

```json
{
  "name": "cc-front-compaction-e2e",
  "model": "sonnet",
  "cwd": "/Users/you/dotfiles",
  "session_assertions": {
    "session_id_present": true,
    "skills_contains": ["cc-front-compaction"],
    "slash_commands_contains": ["cc-front-compaction"]
  },
  "turns": [
    {
      "prompt": "Reply with TOKEN_A",
      "assertions": { "assistant_contains": ["TOKEN_A"] }
    },
    {
      "prompt": "/cc-front-compaction 30",
      "assertions": {
        "assistant_contains": ["/compact"],
        "assistant_not_contains": ["Unsupported:"]
      }
    }
  ],
  "assertions": {
    "assistant_contains": ["/compact"]
  }
}
```

Notes:
- `cwd` and `prompt_file` are resolved relative to the case file location when not absolute.
- For each turn, use exactly one of `prompt` or `prompt_file`.
- Top-level `append_args` apply to every turn.
- Turn-level `append_args` are appended after top-level args.
- Top-level `assertions` in multi-turn mode apply to the **final turn**.
- Keep assertions tolerant; model outputs are non-deterministic.
