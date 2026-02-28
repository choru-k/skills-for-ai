#!/usr/bin/env bash

set -euo pipefail

WEZTERM_BIN="/opt/homebrew/bin/wezterm"
ZELLIJ_BIN="/opt/homebrew/bin/zellij"

wezterm_pane_id="${1:-}"
zellij_session="${2:-}"
zellij_tab_index="${3:-}"
zellij_pane_id="${4:-}"

if [[ -n "$wezterm_pane_id" && -x "$WEZTERM_BIN" ]]; then
  "$WEZTERM_BIN" cli activate-pane --pane-id "$wezterm_pane_id" >/dev/null 2>&1 || true
fi

if [[ -n "$zellij_session" && -n "$zellij_tab_index" && -x "$ZELLIJ_BIN" ]]; then
  "$ZELLIJ_BIN" -s "$zellij_session" action go-to-tab "$zellij_tab_index" >/dev/null 2>&1 || true
fi

if [[ -n "$zellij_session" && -n "$zellij_pane_id" && -x "$ZELLIJ_BIN" ]]; then
  for _ in $(seq 1 24); do
    current_pane="$($ZELLIJ_BIN -s "$zellij_session" action list-clients 2>/dev/null | awk 'NR==2 {print $2}')"
    [[ "$current_pane" == "$zellij_pane_id" ]] && break

    "$ZELLIJ_BIN" -s "$zellij_session" action focus-next-pane >/dev/null 2>&1 || break
    sleep 0.03
  done
fi
