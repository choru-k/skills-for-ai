# mung-notify (Claude Code)

Desktop notification hooks for Claude Code using `mung`.

This is the Claude counterpart to `private/pi/mung-notify` and uses the same metadata-first alert contract.

## Hook lifecycle mapping

- `SessionStart` / `SessionEnd`
  - `mung clear --source <source> --session <sessionId>`
- `Notification` (`permission_prompt` / `elicitation_dialog`)
  - send action notification (`kind=action`) in a stable action lane
- `UserPromptSubmit`
  - clear action lane for the session (`kind=action`)
- `Stop`
  - clear action lane, then send update notification (`kind=update`) using last assistant text from transcript when available

## Mung contract (metadata-first)

Each notification uses:

- `--source` = `${CLAUDE_MUNG_SOURCE:-claude-code}`
- `--session` = Claude `session_id`
- `--kind` = `update` or `action`
- `--dedupe-key`:
  - update lane: `<source>:update:<sessionId>`
  - action lane: `<source>:action:<sessionId>`

Tags are optional and used for grouping:

- source tag: `<source>`
- session tag: `${CLAUDE_MUNG_SESSION_TAG_PREFIX:-cc-session-}<sessionId>`
- action tag: `${CLAUDE_MUNG_ACTION_TAG:-cc-needs-action}`
- focus tier tag: `${CLAUDE_MUNG_FOCUS_TIER_TAG_PREFIX:-cc-focus-tier-}<tier>`

## Focus behavior tiers

When focus metadata is available, notifications include:

- `exact`
- `practical_exact`
- `best_effort`
- `app_only`

Focus is implemented by `hooks/mung-focus.sh` and attached via `--on-click`.

## Files

- `hooks/mung-notify.sh` — main hook handler
- `hooks/mung-focus.sh` — focus helper used by on-click commands
- `hooks/hooks.json` — Claude hooks config

## Install

### Via marketplace (published)

```bash
claude plugin marketplace add choru-k/skills-for-ai
claude plugin install cc-mung-notify
```

### Manual local/public install

1. Copy this directory to a Claude plugin root (example):

   ```bash
   mkdir -p ~/.claude/plugins/mung-notify
   rsync -a public/claude/cc-mung-notify/ ~/.claude/plugins/mung-notify/
   chmod +x ~/.claude/plugins/mung-notify/hooks/mung-notify.sh
   chmod +x ~/.claude/plugins/mung-notify/hooks/mung-focus.sh
   ```

2. Add hook entries to your Claude settings (for example `~/.claude/settings.local.json`) pointing at the script:

   ```json
   {
     "hooks": {
       "SessionStart": [{"matcher":"*","hooks":[{"type":"command","command":"bash ~/.claude/plugins/mung-notify/hooks/mung-notify.sh"}]}],
       "UserPromptSubmit": [{"hooks":[{"type":"command","command":"bash ~/.claude/plugins/mung-notify/hooks/mung-notify.sh"}]}],
       "Notification": [{"matcher":"permission_prompt|elicitation_dialog","hooks":[{"type":"command","command":"bash ~/.claude/plugins/mung-notify/hooks/mung-notify.sh"}]}],
       "Stop": [{"hooks":[{"type":"command","command":"bash ~/.claude/plugins/mung-notify/hooks/mung-notify.sh"}]}],
       "SessionEnd": [{"matcher":"*","hooks":[{"type":"command","command":"bash ~/.claude/plugins/mung-notify/hooks/mung-notify.sh"}]}]
     }
   }
   ```

3. Restart Claude Code (hooks are loaded at session start) and check with `/hooks`.

## Tests

Deterministic hook smoke (no Claude API):

```bash
bash public/claude/cc-mung-notify/tests/test-hook-smoke.sh
```

Live Claude runtime E2E (real `claude -p` run):

```bash
bash public/claude/cc-mung-notify/tests/test-claude-e2e.sh
```

If Claude auth/access is unavailable, the live E2E exits with a clear auth error.

## Environment overrides

Core:

- `CLAUDE_MUNG_COMMAND` (explicit mung path)
- `CLAUDE_MUNG_SOURCE` (default `claude-code`)
- `CLAUDE_MUNG_SOUND` (default `default`)
- `CLAUDE_MUNG_ACTION_ICON` / `CLAUDE_MUNG_UPDATE_ICON`
- `CLAUDE_MUNG_ACTION_TITLE` / `CLAUDE_MUNG_ACTION_MESSAGE`
- `CLAUDE_MUNG_UPDATE_TITLE` / `CLAUDE_MUNG_UPDATE_MESSAGE`
- `CLAUDE_MUNG_DEBUG=1` for stderr debug logs

Focus-related:

- `CLAUDE_MUNG_FOCUS_SCRIPT`
- `CLAUDE_MUNG_TERMINAL=wezterm|ghostty`
- `CLAUDE_MUNG_GHOSTTY_TAB_MODE=single|multi|unknown`
- `CLAUDE_MUNG_TMUX_SESSION`, `CLAUDE_MUNG_TMUX_WINDOW`, `CLAUDE_MUNG_TMUX_PANE`
- `CLAUDE_MUNG_WEZTERM_APP_NAME`, `CLAUDE_MUNG_GHOSTTY_APP_NAME`
