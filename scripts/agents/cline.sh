#!/usr/bin/env bash
# Emit picker rows for running Cline agents inside tmux panes.
#
# Cline reports session history via `cline history --json`. We match running
# cline processes by PID to their active session, or fall back to the most
# recent session when the PID doesn't have a matching entry.
#
# Row: rank \t pane_id \t pid \t agent \t kind \t icon \t age \t loc \t path
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../helpers.sh"

prefix="$(get_tmux_option @agent_cline_prefix 'cline-')"
now="$(date +%s)"

# Find cline PIDs
cline_pids=$(ps -eo pid=,args= 2>/dev/null | grep -i 'cline' | grep -v grep | grep -v '/bin/sh -c' | grep -v 'cline.sh' | awk '{print $1}')
[ -n "$cline_pids" ] || exit 0

# Get session history from Cline
hist=$(cline history --json --limit 50 2>/dev/null)
[ -n "$hist" ] || exit 0

# Get TMUX pane info
pane_info="$(tmux list-panes -a -F $'#{pane_tty}\t#{pane_id}\t#{session_name}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_path}' 2>/dev/null)"
[ -n "$pane_info" ] || exit 0

echo "$cline_pids" | while read -r pid; do
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

  # Find matching session in Cline history — prefer interactive, then by PID, then by recent
  session=$(printf '%s' "$hist" | jq -r --argjson pid "$pid" \
    '[.[] | select(.interactive == true)] |
     (map(select(.pid == $pid)) | first) as $p |
     if $p then $p else first end |
     {status: .status, sessionId: .sessionId, endedAt: .endedAt, startedAt: .startedAt} | @tsv' 2>/dev/null)

  if [ -z "$session" ]; then
    # No history match — treat as active
    icon="$(printf '\033[33m●\033[0m active ')"
    rank=0
    age_mins="-"
    sid=""
  else
    read -r status sid ended_at started_at <<< "$session"

    if [ "$status" = "failed" ]; then
      icon="$(printf '\033[31m●\033[0m failed ')"
      rank=2
    elif [ "$ended_at" != "null" ] && [ -n "$ended_at" ]; then
      # Completed session — compute age from end
      end_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${ended_at%.*}" "+%s" 2>/dev/null || echo "")
      if [ -n "$end_epoch" ]; then
        age_mins=$(( (now - end_epoch) / 60 ))
        [ "$age_mins" -lt 0 ] && age_mins=0
      else
        age_mins="-"
      fi
      icon="$(printf '\033[32m●\033[0m done   ')"
      rank=1
    else
      # Active session
      if [ -n "$started_at" ]; then
        start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${started_at%.*}" "+%s" 2>/dev/null || echo "")
        if [ -n "$start_epoch" ]; then
          age_mins=$(( (now - start_epoch) / 60 ))
          [ "$age_mins" -lt 0 ] && age_mins=0
        else
          age_mins="-"
        fi
      else
        age_mins="-"
      fi
      if [ -n "$age_mins" ] && [ "$age_mins" != "-" ] && [ "$age_mins" -le 1 ]; then
        icon="$(printf '\033[33m●\033[0m active ')"
        rank=0
      else
        icon="$(printf '\033[32m●\033[0m idle  ')"
        rank=1
      fi
    fi
  fi

  kind="$(echo "$tmux_sess" | awk -v p="$prefix" '{ print (index($0, p) == 1) ? "dedicated" : "loose" }')"

  path="$pane_cwd"
  if [ "${path#$HOME}" != "$path" ]; then
    path="~${path#$HOME}"
  fi

  printf "%s\t%s\t%s\tcline\t%s\t%s\t%5s\t%s\t%s\n" \
    "$rank" "$pane_id" "$pid" "$kind" "$icon" "${age_mins}m" "$loc" "$path"
done | sort -t$'\t' -k1,1n -k7,7n
