#!/usr/bin/env bash
# Aggregate picker rows from all supported AI agent backends.
#
# Each backend in scripts/agents/ emits the same 9-column TSV format:
#   rank \t pane_id \t pid \t agent \t kind \t icon \t age \t loc \t path
#
# This script calls them all, concatenates, and sorts: rank asc (what needs
# attention floats up), then age asc (newly idle at the top of its group).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

{
  "$DIR/agents/claude.sh"
  "$DIR/agents/opencode.sh"
  "$DIR/agents/commandcode.sh"
  "$DIR/agents/cline.sh"
  "$DIR/agents/codex.sh"
} | sort -t$'\t' -k1,1n -k7,7n
# rank asc (what needs you floats up), then age asc so whatever just went idle
# sits at the top of its group. -k7,7n reads the leading number of the age field
# ("5m" -> 5; "-" -> 0).
