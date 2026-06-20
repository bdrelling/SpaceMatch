#!/usr/bin/env bash
# PreToolUse guard: the `game-designer` subagent may only Write/Edit inside
# docs/gdd/. Every other agent (including the main agent) is unaffected.
#
# Wired up in .claude/settings.json under hooks.PreToolUse with matcher
# "Write|Edit|MultiEdit|NotebookEdit". Reads the hook payload on stdin.
set -euo pipefail

input="$(cat)"

# Only constrain the game-designer subagent. agent_type is absent for the main
# agent, so everyone else falls through to normal permission handling.
agent_type="$(printf '%s' "$input" | jq -r '.agent_type // empty')"
[[ "$agent_type" == "game-designer" ]] || exit 0

# Write/Edit/MultiEdit use file_path; NotebookEdit uses notebook_path.
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
[[ -n "$file_path" ]] || exit 0

# Canonical docs/gdd dir (this script lives at .claude/hooks/gdd-guard.sh).
gdd_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/docs/gdd"

# Canonicalize the target via its parent dir so `..` and symlinks can't escape.
dir="$(dirname "$file_path")"
base="$(basename "$file_path")"
if resolved="$(cd "$dir" 2>/dev/null && pwd)"; then
  abs="$resolved/$base"
else
  abs="$file_path"
fi

case "$abs" in
  "$gdd_dir"/*) exit 0 ;;  # inside docs/gdd/ — defer to normal permissions
  *)
    jq -n --arg r "game-designer can only write inside docs/gdd/ — blocked write to $file_path" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    exit 0
    ;;
esac
