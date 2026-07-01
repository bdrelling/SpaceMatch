#!/bin/bash
# Godot vendor wrapper — the single entry point for the local Godot toolchain.
#
#   godot.sh check  [targets...]   # parse-check: whole project, or the given .gd files
#   godot.sh import                # rebuild the import/UID cache (whole project)
#   godot.sh test   [targets...]   # gdUnit4 via test.sh: whole suite, or the given paths
#
# Shares godot-bin.sh (binary resolver) with test.sh. `test` delegates to test.sh so its
# battle-tested crash-verdict logic stays verbatim.
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

cmd="${1:-}"
[ "$#" -gt 0 ] && shift

case "$cmd" in
	check)
		GODOT="$("$DIR/godot-bin.sh")" || exit 1
		if [ "$#" -eq 0 ]; then
			"$GODOT" --path source --headless --check-only --quit
			status=$?
		else
			status=0
			for f in "$@"; do
				"$GODOT" --path source --headless --check-only --script "$f" --quit || status=$?
			done
		fi
		echo "EXIT: $status"
		exit $status
		;;
	import)
		GODOT="$("$DIR/godot-bin.sh")" || exit 1
		"$GODOT" --path source --headless --import --quit
		status=$?
		echo "EXIT: $status"
		exit $status
		;;
	test)
		exec "$DIR/test.sh" "$@"
		;;
	*)
		echo "usage: godot.sh <check|import|test> [targets...]" >&2
		exit 2
		;;
esac
