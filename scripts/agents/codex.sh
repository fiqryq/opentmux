#!/usr/bin/env bash
# Emit picker rows for running Codex agents inside tmux panes.
#
# Codex stores thread metadata in ~/.codex/state_5.sqlite. We find codex
# processes via ps, resolve their tmux pane via tty, and match by cwd to
# threads in the DB for activity timestamps.
#
# Row: rank \t pane_id \t pid \t agent \t kind \t icon \t age \t loc \t path
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../helpers.sh"

prefix="$(get_tmux_option @agent_codex_prefix 'codex-')"
now="$(date +%s)"

# Find codex PIDs
codex_pids=$(ps -eo pid=,args= 2>/dev/null | grep -i 'codex' | grep -v grep | grep -v '/bin/sh -c' | grep -v 'codex.sh' | grep -v 'tmux' | awk '{print $1}')
[ -n "$codex_pids" ] || exit 0

# Get TMUX pane info
pane_info="$(tmux list-panes -a -F $'#{pane_tty}\t#{pane_id}\t#{session_name}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_path}' 2>/dev/null)"
[ -n "$pane_info" ] || exit 0

# Fetch thread activity from Codex SQLite DB
db="${CODEX_DB:-$HOME/.codex/state_5.sqlite}"
thread_times=""
if [ -f "$db" ] && command -v sqlite3 >/dev/null 2>&1; then
  thread_times="$(sqlite3 "$db" \
    "SELECT cwd, updated_at, archived FROM threads WHERE archived=0 ORDER BY updated_at DESC LIMIT 50" 2>/dev/null)"
fi

echo "$codex_pids" | while read -r pid; do
  [ -z "$pid" ] && continue

  tty_raw=$(ps -p "$pid" -o tty= 2>/dev/null | tr -d ' ')
  [ -z "$tty_raw" ] && continue
  tty_full="/dev/$tty_raw"

  pane_line="$(echo "$pane_info" | awk -F'\t' -v t="$tty_raw" '$1 == t { print $2, $3, $4, $5; exit }')"
  if [ -z "$pane_line" ]; then
    pane_line="$(echo "$pane_info" | awk -F'\t' -v t="$tty_full" '$1 == t { print $2, $3, $4, $5; exit }')"
  fi
  [ -n "$pane_line" ] || continue

  read -r pane_id tmux_sess loc pane_cwd <<< "$pane_line"

  # Match cwd to thread in DB
  updated=$(echo "$thread_times" | awk -F'|' -v d="$pane_cwd" '$1 == d { printf "%d", $2; exit }')
  age_mins="-"
  rank=2
  icon="$(printf '\033[90m●\033[0m stale ')"

  if [ -n "$updated" ]; then
    age_mins=$(( (now - updated) / 60 ))
    [ "$age_mins" -lt 0 ] && age_mins=0

    if [ "$age_mins" -le 1 ]; then
      icon="$(printf '\033[33m●\033[0m active ')"
      rank=0
    elif [ "$age_mins" -le 30 ]; then
      icon="$(printf '\033[32m●\033[0m idle  ')"
      rank=1
    fi
  fi

  kind="$(echo "$tmux_sess" | awk -v p="$prefix" '{ print (index($0, p) == 1) ? "dedicated" : "loose" }')"

  path="$pane_cwd"
  if [ "${path#$HOME}" != "$path" ]; then
    path="~${path#$HOME}"
  fi

  printf "%s\t%s\t%s\tcodex\t%s\t%s\t%5s\t%s\t%s\n" \
    "$rank" "$pane_id" "$pid" "$kind" "$icon" "${age_mins}m" "$loc" "$path"
done | sort -t$'\t' -k1,1n -k7,7n
