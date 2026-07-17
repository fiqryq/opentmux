#!/usr/bin/env bash
# Emit picker rows for opencode sessions running inside tmux panes.
#
# Opencode stores session metadata in ~/.local/share/opencode/opencode.db (SQLite).
# We match opencode processes by process args, then resolve their tmux pane
# via the tty→pane join. Session activity comes from the DB's time_updated.
#
# Row: rank \t pane_id \t pid \t agent \t kind \t icon \t age \t loc \t path
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../helpers.sh"

prefix="$(get_tmux_option @agent_opencode_prefix 'opencode-')"
now="$(date +%s)"

# Find opencode PIDs. On macOS, comm is truncated to 16 chars, so we grep args.
oc_pids=$(ps -eo pid=,args= 2>/dev/null | grep 'opencode' | grep -v grep | grep -v '/bin/sh -c' | grep -v 'opencode.sh' | awk '{print $1}')
[ -n "$oc_pids" ] || exit 0

# Get TMUX pane info
pane_info="$(tmux list-panes -a -F $'#{pane_tty}\t#{pane_id}\t#{session_name}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_path}' 2>/dev/null)"
[ -n "$pane_info" ] || exit 0

# Fetch recent session activity from opencode's SQLite DB
db="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
session_times=""
if [ -f "$db" ] && command -v sqlite3 >/dev/null 2>&1; then
  session_times="$(sqlite3 "$db" \
    "SELECT directory, time_updated FROM session WHERE time_archived IS NULL ORDER BY time_updated DESC LIMIT 50" 2>/dev/null)"
fi

echo "$oc_pids" | while read -r pid; do
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

  # Find matching session time for this directory
  updated_ms=$(echo "$session_times" | awk -F'|' -v d="$pane_cwd" '$1 == d { printf "%d", $2; exit }')
  age_mins="-"
  rank=2
  icon="$(printf '\033[90m●\033[0m stale ')"

  if [ -n "$updated_ms" ]; then
    updated_sec=$((updated_ms / 1000))
    age_mins=$(( (now - updated_sec) / 60 ))
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

  printf "%s\t%s\t%s\topencode\t%s\t%s\t%5s\t%s\t%s\n" \
    "$rank" "$pane_id" "$pid" "$kind" "$icon" "${age_mins}m" "$loc" "$path"
done | sort -t$'\t' -k1,1n -k7,7n
