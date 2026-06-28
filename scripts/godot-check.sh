#!/bin/bash
godot --path source --headless --check-only --quit
status=$?
echo "EXIT: $status"
exit $status
