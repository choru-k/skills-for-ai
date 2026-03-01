#!/usr/bin/env bash

set -euo pipefail

resolve_bin() {
  local preferred="$1"
  shift || true

  if [[ -x "$preferred" ]]; then
    echo "$preferred"
    return 0
  fi

  for candidate in "$@"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  echo ""
}

WEZTERM_BIN="${WEZTERM_BIN:-$(resolve_bin /opt/homebrew/bin/wezterm wezterm)}"
ZELLIJ_BIN="${ZELLIJ_BIN:-$(resolve_bin /opt/homebrew/bin/zellij zellij)}"
TMUX_BIN="${TMUX_BIN:-$(resolve_bin /opt/homebrew/bin/tmux tmux)}"
OSASCRIPT_BIN="${OSASCRIPT_BIN:-$(command -v osascript || true)}"

terminal_program="${1:-}"
wezterm_pane_id="${2:-}"
zellij_session="${3:-}"
zellij_tab_index="${4:-}"
zellij_pane_id="${5:-}"
tmux_session="${6:-}"
tmux_window="${7:-}"
tmux_pane="${8:-}"

activate_terminal_app() {
  local app_name=""

  case "$terminal_program" in
    wezterm)
      app_name="${CLAUDE_MUNG_WEZTERM_APP_NAME:-${PI_MUNG_WEZTERM_APP_NAME:-WezTerm}}"
      ;;
    ghostty)
      app_name="${CLAUDE_MUNG_GHOSTTY_APP_NAME:-${PI_MUNG_GHOSTTY_APP_NAME:-Ghostty}}"
      ;;
  esac

  if [[ -n "$app_name" && -n "$OSASCRIPT_BIN" ]]; then
    "$OSASCRIPT_BIN" -e "tell application \"$app_name\" to activate" >/dev/null 2>&1 || true
  fi
}

focus_wezterm_pane() {
  if [[ -n "$wezterm_pane_id" && -n "$WEZTERM_BIN" ]]; then
    "$WEZTERM_BIN" cli activate-pane --pane-id "$wezterm_pane_id" >/dev/null 2>&1 || true
  fi
}

focus_zellij() {
  if [[ -n "$zellij_session" && -n "$zellij_tab_index" && -n "$ZELLIJ_BIN" ]]; then
    "$ZELLIJ_BIN" -s "$zellij_session" action go-to-tab "$zellij_tab_index" >/dev/null 2>&1 || true
  fi

  if [[ -n "$zellij_session" && -n "$zellij_pane_id" && -n "$ZELLIJ_BIN" ]]; then
    for _ in $(seq 1 24); do
      current_pane="$($ZELLIJ_BIN -s "$zellij_session" action list-clients 2>/dev/null | awk 'NR==2 {print $2}')"
      [[ "$current_pane" == "$zellij_pane_id" ]] && break

      "$ZELLIJ_BIN" -s "$zellij_session" action focus-next-pane >/dev/null 2>&1 || break
      sleep 0.03
    done
  fi
}

focus_tmux() {
  if [[ -z "$TMUX_BIN" ]]; then
    return 0
  fi

  if [[ -n "$tmux_session" ]]; then
    "$TMUX_BIN" switch-client -t "$tmux_session" >/dev/null 2>&1 || true
  fi

  if [[ -n "$tmux_session" && -n "$tmux_window" ]]; then
    "$TMUX_BIN" select-window -t "${tmux_session}:${tmux_window}" >/dev/null 2>&1 || true
  elif [[ -n "$tmux_window" ]]; then
    "$TMUX_BIN" select-window -t "$tmux_window" >/dev/null 2>&1 || true
  fi

  if [[ -n "$tmux_pane" ]]; then
    "$TMUX_BIN" select-pane -t "$tmux_pane" >/dev/null 2>&1 || true
  fi
}

activate_terminal_app
focus_wezterm_pane
focus_zellij
focus_tmux
