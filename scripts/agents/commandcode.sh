#!/usr/bin/env bash
# Emit picker rows for command-code sessions running inside tmux panes.
#
# Command-code has no daemon API. We find its process via ps, join tty→tmux pane,
# and use process start time for the activity age column.
#
# Row: rank \t pane_id \t pid \t agent \t kind \t icon \t age \t loc \t path
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../helpers.sh"

prefix="$(get_tmux_option @agent_cc_prefix 'cc-')"
now="$(date +%s)"

# Find command-code PIDs
cc_pids=$(ps -eo pid=,args= 2>/dev/null | grep 'command-code' | grep -v grep | grep -v '/bin/sh -c' | awk '{print $1}')
[ -n "$cc_pids" ] || exit 0

# Get TMUX pane info
pane_info="$(tmux list-panes -a -F $'#{pane_tty}\t#{pane_id}\t#{session_name}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_path}' 2>/dev/null)"
[ -n "$pane_info" ] || exit 0

echo "$cc_pids" | while read -r pid; do
  [ -z "$pid" ] && continue

  raw_tty=$(ps -p "$pid" -o tty= 2>/dev/null | tr -d ' ')
  [ -z "$raw_tty" ] && continue
  tty="${raw_tty#/dev/}"
  tty_full="/dev/$tty"

  lstart=$(ps -p "$pid" -o lstart= 2>/dev/null)
  start_epoch=""
  if [ -n "$lstart" ]; then
    start_epoch=$(date -j -f "%a %b %d %T %Y" "$lstart" "+%s" 2>/dev/null || echo "")
  fi

  pane_line="$(echo "$pane_info" | awk -F'\t' -v t="$tty" '$1 == t { print $2, $3, $4, $5; exit }')"
  if [ -z "$pane_line" ]; then
    pane_line="$(echo "$pane_info" | awk -F'\t' -v t="$tty_full" '$1 == t { print $2, $3, $4, $5; exit }')"
  fi
  [ -n "$pane_line" ] || continue

  read -r pane_id tmux_sess loc pane_cwd <<< "$pane_line"

  age_mins="-"
  if [ -n "$start_epoch" ]; then
    age_mins=$(( (now - start_epoch) / 60 ))
    [ "$age_mins" -lt 0 ] && age_mins=0
  fi

  if [ -z "$start_epoch" ] || [ "$age_mins" -le 1 ]; then
    icon="$(printf '\033[33m●\033[0m active ')"
    rank=0
  elif [ "$age_mins" -le 30 ]; then
    icon="$(printf '\033[32m●\033[0m idle  ')"
    rank=1
  else
    icon="$(printf '\033[90m●\033[0m stale ')"
    rank=2
  fi

  kind="$(echo "$tmux_sess" | awk -v p="$prefix" '{ print (index($0, p) == 1) ? "dedicated" : "loose" }')"

  path="$pane_cwd"
  if [ "${path#$HOME}" != "$path" ]; then
    path="~${path#$HOME}"
  fi

  printf "%s\t%s\t%s\tcc\t%s\t%s\t%5s\t%s\t%s\n" \
    "$rank" "$pane_id" "${pid:-}" "$kind" "$icon" "${age_mins}m" "$loc" "$path"
done | sort -t$'\t' -k1,1n -k7,7n
