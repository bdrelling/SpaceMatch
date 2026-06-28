#!/bin/bash
godot --path source --headless --import --quit
status=$?
echo "EXIT: $status"
exit $status
