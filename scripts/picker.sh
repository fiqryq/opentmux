#!/usr/bin/env bash
# Interactive picker for running AI agents (Claude, OpenCode, Command-Code).
#
#   picker.sh           fzf picker; on enter, jumps to the chosen agent.
#   picker.sh --list    print the rows only (used by fzf's ctrl-x reload).
#
# Rows come from agents_all.sh, which aggregates all agent backends.
# Two kinds of row jump differently:
#   dedicated  in an agent-* session this plugin launched — resumed in the popup,
#              over the window it was launched from.
#   loose      an agent running in any other pane — focused in place.
#
# Row format (9 cols, tab-separated):
#   rank \t pane_id \t pid \t agent \t kind \t icon \t age \t loc \t path
# Display shows cols 4,6,7,8,9 (agent, icon, age, loc, path)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/helpers.sh"

[ "${1:-}" = '--list' ] && exec "$DIR/agents_all.sh"

command -v fzf >/dev/null 2>&1 || {
  tmux display-message "tmux-agent-session-manager: fzf is required for the picker"
  exit 0
}

self="$DIR/picker.sh"
export FZF_DEFAULT_OPTS=''
export AGENT_PICKER="$self"

# Arbitrary user fzf options (e.g. custom --bind or --preview-window)
extra_opts=()
fzf_options="$(get_tmux_option @agent_fzf_options '')"
[ -n "$fzf_options" ] && eval "extra_opts=($fzf_options)"

# ctrl-x kills the agent process: a dedicated session dies with its last window,
# while a loose pane keeps the shell that hosted it. The reload waits a beat so
# backends can pick up the change.
sel=$("$DIR/agents_all.sh" | fzf --ansi --delimiter='\t' --with-nth=4,6,7,8,9 \
  --reverse --cycle --header='Agents · enter: jump · ctrl-x: kill' \
  --preview='tmux capture-pane -ept {2}' --preview-window='up,70%,follow' \
  --bind="ctrl-x:execute-silent(kill {3} 2>/dev/null; sleep 0.3)+reload(sleep 0.3; $self --list)" \
  ${extra_opts[@]+"${extra_opts[@]}"})

[ -z "$sel" ] && exit 0
pane=$(printf '%s' "$sel" | cut -f2)
kind=$(printf '%s' "$sel" | cut -f5)
agent=$(printf '%s' "$sel" | cut -f4)

parent=$(tmux show-options -gqv @agent_parent 2>/dev/null)
session=$(tmux display-message -p -t "$pane" '#{session_name}' 2>/dev/null)

if [ "$kind" = loose ]; then
  # Focus the pane in place on the outer client. This popup closes on its own
  # when the script exits.
  if [ -n "$parent" ]; then
    tmux switch-client -c "$parent" -t "$session" 2>/dev/null
  else
    tmux switch-client -t "$session" 2>/dev/null
  fi
  tmux select-window -t "$pane" 2>/dev/null
  tmux select-pane -t "$pane" 2>/dev/null
  exit 0
fi

# Dedicated: move the parent client to the window the session was launched from,
# focus the chosen agent's window inside that session, then resume it in THIS
# popup. Falls back to resuming over the current window when origin/parent are
# unknown.
origin=$(tmux show-options -qv -t "$session" @agent_origin 2>/dev/null)
[ -n "$origin" ] && [ -n "$parent" ] &&
  tmux switch-client -c "$parent" -t "$origin" 2>/dev/null

tmux select-window -t "$pane" 2>/dev/null
tmux select-pane -t "$pane" 2>/dev/null
tmux attach-session -t "$session"
