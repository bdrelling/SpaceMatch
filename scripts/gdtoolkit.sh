#!/bin/bash
# gdtoolkit vendor wrapper — gdlint / gdformat / install.
# See armory/docs/languages/gdscript/linting.md.
#
#   gdtoolkit.sh lint   [targets...]            # gdlint (report-only, never writes)
#   gdtoolkit.sh format [--write] [targets...]  # gdformat; dry-run (--check) unless --write
#   gdtoolkit.sh install                        # pipx install gdtoolkit (pinned 4.*)
#
# targets: .gd files or dirs. No targets => all .gd under source/, excluding addons/.
set -o pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"

# Print the target file list: explicit args verbatim, else the whole project minus addons.
resolve_files() {
	if [ "$#" -gt 0 ]; then
		printf '%s\n' "$@"
	else
		find "$ROOT/source" -name '*.gd' -not -path '*/addons/*'
	fi
}

cmd="${1:-}"
[ "$#" -gt 0 ] && shift

case "$cmd" in
	lint)
		files=()
		while IFS= read -r f; do files+=("$f"); done < <(resolve_files "$@")
		[ "${#files[@]}" -eq 0 ] && { echo "gdtoolkit.sh: no .gd files"; exit 0; }
		exec gdlint "${files[@]}"
		;;
	format)
		write=0
		if [ "${1:-}" = "--write" ]; then write=1; shift; fi
		files=()
		while IFS= read -r f; do files+=("$f"); done < <(resolve_files "$@")
		[ "${#files[@]}" -eq 0 ] && { echo "gdtoolkit.sh: no .gd files"; exit 0; }
		if [ "$write" -eq 1 ]; then
			exec gdformat "${files[@]}"
		else
			# Dry-run: --check reports files that need formatting and exits non-zero; it never writes.
			exec gdformat --check "${files[@]}"
		fi
		;;
	install)
		if command -v gdlint >/dev/null 2>&1; then
			echo "gdtoolkit already installed"
			exit 0
		fi
		if ! command -v pipx >/dev/null 2>&1; then
			if command -v brew >/dev/null 2>&1; then
				echo "pipx not found — installing via Homebrew..."
				brew install pipx || exit 1
			else
				echo "gdtoolkit.sh: pipx not found. Install it first (e.g. 'brew install pipx'), then re-run." >&2
				exit 1
			fi
		fi
		exec pipx install "gdtoolkit==4.*"
		;;
	*)
		echo "usage: gdtoolkit.sh <lint|format [--write]|install> [targets...]" >&2
		exit 2
		;;
esac
