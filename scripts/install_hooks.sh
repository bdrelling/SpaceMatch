#!/bin/bash
# Copy repo-tracked git hooks (scripts/hooks/*) into .git/hooks/. Run once per clone;
# wired into `make setup`. Idempotent — safe to re-run.
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
HOOKS_SRC="$DIR/hooks"
HOOKS_DST="$ROOT/.git/hooks"

[ -d "$HOOKS_DST" ] || { echo "install_hooks.sh: $HOOKS_DST not found (not a git checkout?)" >&2; exit 1; }

for hook in "$HOOKS_SRC"/*; do
	[ -f "$hook" ] || continue
	name="$(basename "$hook")"
	cp "$hook" "$HOOKS_DST/$name"
	chmod +x "$HOOKS_DST/$name"
	echo "installed hook: $name"
done
