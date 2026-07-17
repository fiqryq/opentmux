#!/usr/bin/env bash
# Emit picker rows for running Claude agents inside tmux panes.
#
# Row: rank \t pane_id \t pid \t agent \t kind \t icon \t age \t loc \t path
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/../helpers.sh"

agents="$(claude agents --json 2>/dev/null)" || exit 0
rows="$(printf '%s' "$agents" |
  jq -r '.[] | select(.kind == "interactive") | [.pid, .status, .sessionId, .cwd] | @tsv' 2>/dev/null)"
[ -n "$rows" ] || exit 0

mtimes="$(printf '%s\n' "$rows" | cut -f3 | while IFS= read -r sid; do
  printf 'M\t%s\t%s\n' "$sid" "$(claude_transcript_mtime "$sid")"
done)"

{
  ps -Ao pid=,tty= 2>/dev/null | awk '{ print "P\t" $1 "\t" $2 }'
  tmux list-panes -a -F $'T\t#{pane_tty}\t#{pane_id}\t#{session_name}\t#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null
  printf '%s\n' "$mtimes"
  printf '%s\n' "$rows" | sed $'s/^/A\t/'
} | awk -F'\t' -v now="$(date +%s)" -v home="$HOME" \
  -v prefix="$(get_tmux_option @agent_claude_prefix 'claude-')" '
  $1 == "P" { tty_of[$2] = $3; next }
  $1 == "T" { sub(/^\/dev\//, "", $2); pane[$2] = $3; sess[$2] = $4; loc[$2] = $5; next }
  $1 == "M" { seen_at[$2] = $3; next }
  $1 == "A" {
    tty = tty_of[$2]
    if (tty == "" || !(tty in pane)) next

    if      ($3 == "waiting") { icon = "\033[33m●\033[0m waiting"; rank = 0 }
    else if ($3 == "idle")    { icon = "\033[32m●\033[0m idle   "; rank = 1 }
    else if ($3 == "busy")    { icon = "\033[31m●\033[0m working"; rank = 3 }
    else                      { icon = "\033[90m●\033[0m   ?    "; rank = 2 }

    age = (seen_at[$4] != "") ? int((now - seen_at[$4]) / 60) "m" : "-"
    kind = (index(sess[tty], prefix) == 1) ? "dedicated" : "loose"

    path = $5
    if (index(path, home) == 1) path = "~" substr(path, length(home) + 1)

    printf "%s\t%s\t%s\tclaude\t%s\t%s\t%5s\t%s\t%s\n",
      rank, pane[tty], $2, kind, icon, age, loc[tty], path
  }
' | sort -t$'\t' -k1,1n -k7,7n
