#!/usr/bin/env bash
# Actually launches a specific agent in a tmux popup. Called from launch.sh's
# display-menu via run-shell. Reads path and origin from tmux globals set by
# launch.sh.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/helpers.sh"

agent="${1:-claude}"
path="$(get_tmux_option @agent_launch_path "$PWD")"
window="$(get_tmux_option @agent_launch_origin '')"

prefix="$(agent_prefix "$agent")"
cmd="$(agent_command "$agent")"
args="$(get_tmux_option "@agent_${agent}_args" '')"
[ -n "$args" ] && cmd="$cmd $args"
w="$(get_tmux_option @agent_popup_width '90%')"
h="$(get_tmux_option @agent_popup_height '90%')"

session="${prefix}$(session_hash "$path")"

if tmux has-session -t "$session" 2>/dev/null; then
  if ! tmux list-windows -t "$session" 2>/dev/null | grep -q .; then
    tmux kill-session -t "$session"
    tmux new-session -d -s "$session" -c "$path" "$cmd"
    tmux set-option -t "$session" detach-on-destroy on
    tmux set-option -t "$session" status off
  elif tmux list-clients -t "$session" 2>/dev/null | grep -q .; then
    tmux display-message "$(agent_label "$agent") already open"
    exit 0
  fi
else
  tmux new-session -d -s "$session" -c "$path" "$cmd"
  tmux set-option -t "$session" detach-on-destroy on
  tmux set-option -t "$session" status off
fi

[ -n "$window" ] && tmux set-option -t "$session" @agent_origin "$window"

tmux display-popup -w "$w" -h "$h" -E "tmux attach-session -t $session"
