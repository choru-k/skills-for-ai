#!/usr/bin/env bash
# Reads JSONL from stdin, pretty-prints AI steps to the terminal, and writes
# the final response text to a file.
#
# Usage: parse-ai-stream.sh <ai> <raw-file>
#   ai       — "gemini" or "codex"
#   raw-file — path where clean response text is accumulated

set -uo pipefail

AI="${1:?Usage: parse-ai-stream.sh <ai> <raw-file>}"
RAW_FILE="${2:?}"

# ─── Colors ───────────────────────────────────────────────────────────────────

YELLOW='\033[33m'
CYAN='\033[36m'
DIM='\033[2m'
RESET='\033[0m'

# ─── Clear output file ───────────────────────────────────────────────────────

> "$RAW_FILE"

# ─── Parse JSONL stream ───────────────────────────────────────────────────────

# Use jq to filter and format the entire stream at once.
# Using --unbuffered (-u) is critical for real-time streaming.
# NOTE: We use RS (\x1e) as field delimiter instead of @tsv because bash `read`
# with IFS=$'\t' collapses consecutive tabs (empty fields), breaking field alignment.
RS=$'\x1e'
jq --unbuffered -r '
  select(type == "object" or (type == "string" and startswith("{"))) |
  if type == "string" then (try fromjson catch null) else . end |
  select(. != null) |
  [.type, .content, .tool_name, .status, .item.type, .item.text, .item.command, .item.exit_code, .item.query] |
  map(
    if . == null then ""
    elif type == "number" then tostring
    else gsub("\n"; "\\n") | gsub("\r"; "\\r")
    end
  ) | join("\u001e")
' | while IFS="$RS" read -r type content tool_name status item_type item_text item_cmd item_exit item_query; do
  case "$AI" in
    gemini)
      case "$type" in
        tool_use)
          [[ -n "$tool_name" && "$tool_name" != "null" ]] && printf "${YELLOW}🔧 %s${RESET}\n" "$tool_name"
          ;;
        tool_result)
          [[ -n "$status" && "$status" != "null" ]] && printf "${DIM}   ✓ %s${RESET}\n" "$status"
          ;;
        message)
          if [[ -n "$content" && "$content" != "null" ]]; then
            # Unescape TSV-escaped content (handles \n, \t, etc.)
            content=$(printf '%b' "$content")
            printf "%s" "$content"
            printf "%s" "$content" >> "$RAW_FILE"
          fi
          ;;
      esac
      ;;
    codex)
      case "$type" in
        item.completed)
          case "$item_type" in
            reasoning)
              if [[ -n "$item_text" && "$item_text" != "null" ]]; then
                item_text=$(printf '%b' "$item_text")
                printf "${CYAN}💭 %s${RESET}\n" "$item_text"
              fi
              ;;
            command_execution)
              [[ -n "$item_cmd" && "$item_cmd" != "null" ]] && printf "${YELLOW}⚡ %s → exit %s${RESET}\n" "$item_cmd" "$item_exit"
              ;;
            agent_message)
              if [[ -n "$item_text" && "$item_text" != "null" ]]; then
                item_text=$(printf '%b' "$item_text")
                printf "%s" "$item_text"
                printf "%s" "$item_text" >> "$RAW_FILE"
              fi
              ;;
            web_search)
              if [[ -n "$item_query" && "$item_query" != "null" ]]; then
                item_query=$(printf '%b' "$item_query")
                printf "${YELLOW}🔍 %s${RESET}\n" "$item_query"
              else
                printf "${YELLOW}🔍 web search${RESET}\n"
              fi
              ;;
          esac
          ;;
      esac
      ;;
  esac
done

# Trailing newline after accumulated text
printf "\n"
