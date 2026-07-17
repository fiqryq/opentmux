#!/usr/bin/env bash
# Shared helpers for tmux-agent-session-manager.

# get_tmux_option <option-name> <default>
# Echoes the global tmux option value, or the default when unset/empty.
get_tmux_option() {
  local value
  value="$(tmux show-option -gqv "$1" 2>/dev/null)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$2"
  fi
}

# session_hash <string>
# Short, stable, portable 8-char hash for deriving a session name from a path.
# Prefers md5sum (Linux), falls back to md5 (macOS) then shasum. The trailing
# newline matches the conventional `echo "$path" | md5sum` scheme, so it stays
# compatible with sessions created that way.
session_hash() {
  local out
  if command -v md5sum >/dev/null 2>&1; then
    out="$(printf '%s\n' "$1" | md5sum)"
  elif command -v md5 >/dev/null 2>&1; then
    out="$(printf '%s\n' "$1" | md5 -q)"
  else
    out="$(printf '%s\n' "$1" | shasum)"
  fi
  printf '%s' "${out%% *}" | cut -c1-8
}

# file_mtime <path>
# Epoch seconds of a file's last modification. GNU stat (Linux) is tried first,
# then BSD (macOS); each rejects the other's flag, so the fallback is unambiguous.
file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

# ---------- agent-type helpers ----------

# agent_prefix <agent-name>
# Maps an agent name (claude, opencode, cc, cline, codex) to its session name prefix.
agent_prefix() {
  case "$1" in
    claude)     get_tmux_option @agent_claude_prefix 'claude-' ;;
    opencode)   get_tmux_option @agent_opencode_prefix 'opencode-' ;;
    cc)         get_tmux_option @agent_cc_prefix 'cc-' ;;
    cline)      get_tmux_option @agent_cline_prefix 'cline-' ;;
    codex)      get_tmux_option @agent_codex_prefix 'codex-' ;;
    *)          printf '%s-' "$1" ;;
  esac
}

# agent_command <agent-name>
# Maps an agent name to its launch command.
agent_command() {
  case "$1" in
    claude)     get_tmux_option @agent_claude_cmd 'claude' ;;
    opencode)   get_tmux_option @agent_opencode_cmd 'opencode' ;;
    cc)         get_tmux_option @agent_cc_cmd 'command-code' ;;
    cline)      get_tmux_option @agent_cline_cmd 'cline' ;;
    codex)      get_tmux_option @agent_codex_cmd 'codex' ;;
    *)          printf '%s' "$1" ;;
  esac
}

# agent_label <agent-name>
# Maps an agent name to its human-readable label for the picker.
agent_label() {
  case "$1" in
    claude)     echo "Claude" ;;
    opencode)   echo "OpenCode" ;;
    cc)         echo "Command Code" ;;
    cline)      echo "Cline" ;;
    codex)      echo "Codex" ;;
    *)          echo "$1" ;;
  esac
}

# is_agent_session <session-name>
# Returns 0 (true) if the session name starts with any known agent prefix.
is_agent_session() {
  local s="$1"
  local prefixes
  prefixes="$(agent_prefix claude) $(agent_prefix opencode) $(agent_prefix cc) $(agent_prefix cline) $(agent_prefix codex)"
  for prefix in $prefixes; do
    [[ "$s" == "$prefix"* ]] && return 0
  done
  return 1
}

# ---------- per-agent mtime helpers ----------

# claude_transcript_mtime <session-id>
# Epoch seconds of the last write to that Claude session's transcript.
claude_transcript_mtime() {
  local base f
  base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  for f in "$base"/projects/*/"$1".jsonl; do
    [ -f "$f" ] && {
      file_mtime "$f"
      return
    }
  done
}

# opencode_transcript_mtime <session-id>
# Epoch seconds of the last update for an opencode session.
opencode_transcript_mtime() {
  local db f
  db="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
  [ -f "$db" ] && command -v sqlite3 >/dev/null 2>&1 && {
    f="$(sqlite3 "$db" "SELECT printf('%d', time_updated / 1000) FROM session WHERE id='$1'" 2>/dev/null)"
    [ -n "$f" ] && printf '%s' "$f" && return
  }
}

# commandcode_transcript_mtime <session-id>
# Epoch seconds of the last write to a command-code session's JSONL file.
commandcode_transcript_mtime() {
  local base f
  base="${COMMANDCODE_HOME:-$HOME/.commandcode}"
  for f in "$base"/projects/*/"$1".jsonl; do
    [ -f "$f" ] && {
      file_mtime "$f"
      return
    }
  done
}

# cline_transcript_mtime <session-id>
# Epoch seconds of the last write to a cline session's messages file.
cline_transcript_mtime() {
  local sid="$1"
  local f
  f="${CLINE_DATA_DIR:-$HOME/.cline}/data/sessions/${sid}/${sid}.messages.json"
  [ -f "$f" ] && { file_mtime "$f"; return; }
}

# codex_transcript_mtime <thread-id>
# Epoch seconds of the last update for a codex thread from its SQLite DB.
codex_transcript_mtime() {
  local db tid
  db="${CODEX_DB:-$HOME/.codex/state_5.sqlite}"
  tid="$1"
  [ -f "$db" ] && command -v sqlite3 >/dev/null 2>&1 && {
    sqlite3 "$db" "SELECT updated_at FROM threads WHERE id='$tid'" 2>/dev/null
    return
  }
}
