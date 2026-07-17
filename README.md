# opentmux

Run AI coding agents — [Claude Code](https://claude.com/claude-code),
[Cline](https://cline.bot),
[Codex](https://github.com/openai/codex),
[OpenCode](https://github.com/sst/opencode),
[Command-Code](https://github.com/commandcode-ai) — on tmux session.

![demo](docs/CleanShot%202026-07-18%20at%2004.33.00.gif)

- `prefix` + `y` — launch an agent for the current directory
- `prefix` + `u` — picker with live preview and status (`working`/`waiting`/`idle`)

## Prerequisites

- **tmux ≥ 3.2**, **[fzf](https://github.com/junegunn/fzf)**, **[jq](https://jqlang.org/)**
- **sqlite3** (needed for OpenCode and Codex session tracking)
- One or more of: [Claude Code](https://claude.com/claude-code),
  [Cline](https://cline.bot),
  [Codex](https://github.com/openai/codex),
  [OpenCode](https://github.com/sst/opencode),
  [Command-Code](https://github.com/commandcode-ai)
- bash, macOS or Linux

## Install

**tpm:** add `set -g @plugin 'fiqryq/opentmux'` to `~/.tmux.conf`, then `prefix` + <kbd>I</kbd>.

**Manual:**

```sh
git clone https://github.com/fiqryq/opentmux ~/clone/path
```

Then add to `~/.tmux.conf` and reload:

```tmux
run-shell ~/clone/path/tmux_agent_session_manager.tmux
```

## Usage

| Key            | Action                   |
| -------------- | ------------------------ |
| `prefix` + `y` | Launch agent for cwd     |
| `prefix` + `u` | Open the agent picker    |

Inside the picker:

| Key             | Action           |
| --------------- | ---------------- |
| `enter`         | Jump to agent    |
| `ctrl-x`        | Kill agent       |
| `↑/↓` / filter  | fzf navigation   |

## Options

```tmux
set -g @agent_launch_key        'y'
set -g @agent_list_key          'u'
set -g @agent_popup_width       '90%'
set -g @agent_popup_height      '90%'
set -g @agent_fzf_options       ''

set -g @agent_claude_prefix     'claude-'
set -g @agent_claude_cmd        'claude'
set -g @agent_claude_args       ''

set -g @agent_opencode_prefix   'opencode-'
set -g @agent_opencode_cmd      'opencode'
set -g @agent_opencode_args     ''

set -g @agent_cc_prefix         'cc-'
set -g @agent_cc_cmd            'command-code'
set -g @agent_cc_args           ''

set -g @agent_cline_prefix      'cline-'
set -g @agent_cline_cmd         'cline'
set -g @agent_cline_args        ''

set -g @agent_codex_prefix      'codex-'
set -g @agent_codex_cmd         'codex'
set -g @agent_codex_args        ''
```

## How it works

- `prefix` + `y` opens a menu to pick an agent, then creates a detached tmux session at the current directory.
- Each agent gets a stable session name derived from its directory hash (e.g. `claude-a3f8b2c1`), so re-opening reattaches rather than duplicating.
- Agents are identified by their _process_ (not session), so running multiple agents in the same directory gives each its own picker row.
- The picker shows live `capture-pane` previews of each agent's terminal. `enter` jumps to it, `ctrl-x` kills the process.
- Status dots come from each agent's own API (`claude agents --json`, `cline history --json`, OpenCode/Codex SQLite DBs, Command-Code JSONL transcripts).
- Rows sort by urgency: waiting/animated agents float to the top, idle ones below, working ones at the bottom.
- Sessions auto-cleanup when the agent process `/exit`s (via `detach-on-destroy`).
- `prefix` + `u` from inside a popup detaches it first, so the picker opens full-size on the parent client — no popup-in-popup.

## Credits

Originally forked from [craftzdog/tmux-claude-session-manager](https://github.com/craftzdog/tmux-claude-session-manager).
