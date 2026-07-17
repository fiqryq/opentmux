#!/usr/bin/env bash
# Open the session picker in a popup. Handles the case of being called from
# inside an agent session popup (claude-*, opencode-*, cc-*) by closing the
# overlay first, waiting for teardown, then reopening the picker on the outer
# client.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/helpers.sh"

w="$(get_tmux_option @agent_popup_width '90%')"
h="$(get_tmux_option @agent_popup_height '90%')"

# The client that pressed the key, and the session it is currently attached to.
me="${1:-}"
my_session="$(tmux list-clients -F '#{client_name} #{session_name}' 2>/dev/null |
  awk -v me="$me" '$1 == me { print $2; exit }')"

# open_picker <host>  — show the picker popup on <host>, or on the default client
# when <host> is empty. Returns display-popup's own exit status.
open_picker() {
  if [ -n "$1" ]; then
    tmux display-popup -c "$1" -w "$w" -h "$h" -E "$DIR/picker.sh"
  else
    tmux display-popup -w "$w" -h "$h" -E "$DIR/picker.sh"
  fi
}

if is_agent_session "$my_session"; then
  # Inside a session popup: close it, then reopen the picker on the outer client.
  tmux detach-client -s "$my_session"
  for _ in $(seq 1 100); do
    tmux list-clients -F '#{session_name}' 2>/dev/null | grep -qx "$my_session" || break
    sleep 0.05
  done
  host="$(tmux show-options -gqv @agent_parent 2>/dev/null)"
  # A stale parent would make every retry fail; fall back to the default client.
  if [ -n "$host" ] && ! tmux list-clients -F '#{client_name}' 2>/dev/null | grep -qx "$host"; then
    host=''
  fi

  sleep 0.1
  rc=0
  for _ in $(seq 1 40); do
    before=$SECONDS
    open_picker "$host"
    rc=$?
    { [ "$rc" -eq 0 ] || [ $((SECONDS - before)) -ge 1 ]; } && break
    sleep 0.1
  done
  exit "$rc"
fi

# Normal case: this client is already the host, with no overlay to race.
host="$me"
tmux set-option -g @agent_parent "$host"
open_picker "$host"
