#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="$("$DIR/godot-bin.sh")" || exit 1
"$GODOT" --path source --headless --check-only --quit
status=$?
echo "EXIT: $status"
exit $status
