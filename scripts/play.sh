#!/usr/bin/env bash
# Launch the game (no editor). Forwards any extra args to godot.
# Fails non-zero on script/parse errors — Godot itself logs them and continues,
# which masks broken scripts behind a window that "looks fine."
# Examples:
#   ./scripts/play.sh
#   ./scripts/play.sh --quit-after 5
#   ./scripts/play.sh --windowed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../source"

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

set +e
godot --path "$PROJECT_DIR" "$@" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if grep -qE '^(SCRIPT ERROR|ERROR: Failed to (load|instantiate))' "$LOG"; then
    echo "" >&2
    echo "play.sh: script/parse errors detected above — failing." >&2
    exit 1
fi

exit "$status"
