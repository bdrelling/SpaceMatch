#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="$("$DIR/godot-bin.sh")" || exit 1
"$GODOT" --path source --headless --import --quit
status=$?
echo "EXIT: $status"
exit $status
