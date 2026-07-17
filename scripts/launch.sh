#!/usr/bin/env bash
# Launch an AI agent session in a tmux display-menu, then creates (or re-attaches
# to) a session for the selected agent.
# Args: <dir> [origin-window-id]   (both expanded by run-shell in the binding)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/helpers.sh"

path="${1:-$PWD}"
window="${2:-}"

# Guard against recursive popup launches
if is_agent_session "$(tmux display-message -p '#S')"; then
  tmux display-message 'Popup window already open'
  exit 0
fi

# Show agent picker via display-menu. Each entry runs launch_agent with args.
# We need to pass path and window through tmux options since run-shell doesn't
# inherit script variables.
tmux set-option -g @agent_launch_path "$path"
tmux set-option -g @agent_launch_origin "$window"

tmux display-menu -T 'AI Agent' \
  'Claude'       c "run-shell \"$DIR/launch_agent.sh claude\"" \
  'Cline'        i "run-shell \"$DIR/launch_agent.sh cline\"" \
  'Codex'        x "run-shell \"$DIR/launch_agent.sh codex\"" \
  'OpenCode'     o "run-shell \"$DIR/launch_agent.sh opencode\"" \
  'Command Code' m "run-shell \"$DIR/launch_agent.sh cc\""
