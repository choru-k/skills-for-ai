# mung-notify (Claude) E2E

## Goal
Validate the Claude hook bridge to `mung` with real Claude runtime events, plus deterministic hook-only checks.

## Automated tests

### 1) Hook-level deterministic smoke (no Claude API needed)

```bash
bash public/claude/cc-mung-notify/tests/test-hook-smoke.sh
```

Covers:
- `SessionStart` clear
- action notification add path
- `Stop` update add path
- metadata-first fields (`source/session/kind/dedupe-key`)

### 2) Live Claude runtime E2E (real Claude CLI run)

```bash
bash public/claude/cc-mung-notify/tests/test-claude-e2e.sh
```

This runs real `claude -p` with `--plugin-dir public/claude/cc-mung-notify`, injects a fake `mung` binary in PATH, then asserts captured calls from actual hook execution.

Covers:
- real lifecycle-triggered session clear
- real prompt/stop action-lane clear
- real stop update notification add with update dedupe lane
- metadata-first scoping for source/session

Notes:
- Requires working Claude auth/access.
- If Claude is not logged in (or org access is unavailable), the script exits with a clear auth error.

## Manual focus checks

For click-to-focus behavior (`--on-click` payload), use manual runs in your preferred terminal stack (wezterm/ghostty + tmux/zellij), then inspect mung entries and click behavior.

## Expected lanes

- Action lane dedupe: `<source>:action:<sessionId>`
- Update lane dedupe: `<source>:update:<sessionId>`
