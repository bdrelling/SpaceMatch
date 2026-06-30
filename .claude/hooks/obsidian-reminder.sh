#!/usr/bin/env bash
# PreToolUse reminder: docs/obsidian/ is a SYMLINK into an external iCloud vault,
# so the harness Glob/Grep (and plain find/rg/grep) are blind to it. Fires on the
# read/search tools and, only when the tool input references docs/obsidian, injects
# context nudging toward symlink-following search and the `obsidian` skill/CLI.
# Never blocks — it only adds context.
#
# Wired up in .claude/settings.json under hooks.PreToolUse with matcher
# "Bash|Read|Grep|Glob". Reads the hook payload on stdin.
set -euo pipefail

input="$(cat)"

# Serialize the whole tool_input and look for a docs/obsidian reference anywhere in
# it — covers Bash .command, Read .file_path, Grep/Glob .path/.pattern in one check.
tool_input="$(printf '%s' "$input" | jq -r '.tool_input // empty | tostring')"
printf '%s' "$tool_input" | grep -q 'docs/obsidian' || exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: "docs/obsidian/ is a SYMLINK into an external iCloud vault — the harness Glob/Grep and plain find/rg/grep are blind to it. To search the vault use `find -L docs/obsidian`, `rg --follow … docs/obsidian`, or `grep -R … docs/obsidian`, and `ls docs/obsidian/` before guessing a subfolder. For vault-aware ops (full-vault search, dataview, links/tags, daily notes, templates) prefer the obsidian skill and the `obsidian` CLI over raw file reads."
  }
}'
