#!/bin/bash
# Resolve the godot binary path: PATH first, then the known Docker container
# fallback (/usr/local/bin/godot). Prints the path; exits nonzero if not found.
# Shared by godot-check.sh, godot-import.sh, and test.sh so all three agree.
if command -v godot >/dev/null 2>&1; then
  command -v godot
elif [ -x /usr/local/bin/godot ]; then
  echo /usr/local/bin/godot
else
  echo "godot-bin.sh: godot binary not found (not on PATH, not at /usr/local/bin/godot)" >&2
  exit 1
fi
