#!/usr/bin/env bash
# tmux-agent-session-manager
#
# Multi-agent tmux session manager. Press prefix+y to pick an AI agent (Claude,
# Cline, Codex, OpenCode, or Command-Code) and launch it in a popup over the
# current directory.
# Press prefix+u to list all running agents, monitor their status, and jump
# between them.
#
# Install via TPM:
#   set -g @plugin 'craftzdog/tmux-agent-session-manager'
#
# Or source directly in tmux.conf:
#   run-shell /path/to/tmux_agent_session_manager.tmux

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/scripts/helpers.sh"

launch_key="$(get_tmux_option @agent_launch_key 'y')"
list_key="$(get_tmux_option @agent_list_key 'u')"

# prefix+y: pick an agent type, then launch it in a popup for the current directory.
tmux bind-key "$launch_key" \
  run-shell "$CURRENT_DIR/scripts/launch.sh '#{q:pane_current_path}' '#{q:window_id}'"

# prefix+u: open the agent picker. When pressed from inside a session popup,
# list.sh closes that popup first so the picker opens full-size on the outer client.
tmux bind-key "$list_key" \
  run-shell "$CURRENT_DIR/scripts/list.sh '#{q:client_name}'"
