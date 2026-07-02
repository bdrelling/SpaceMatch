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

# Print the .gd file list to operate on. source/addons/ is NEVER included — gdformat has no
# exclude config, so exclusion has to happen here. No targets => the whole source/ tree.
# Directory targets are expanded (minus addons); file targets pass through (unless under addons).
resolve_files() {
	if [ "${1:-}" = "--staged" ]; then
		# Staged .gd under source/, minus addons — the commit / verify scope.
		git -C "$ROOT" diff --cached --name-only --diff-filter=ACM -- source \
			| grep '\.gd$' | grep -v '/addons/' | sed "s#^#$ROOT/#"
		return
	fi
	local roots=("$@")
	[ "${#roots[@]}" -eq 0 ] && roots=("$ROOT/source")
	local r
	for r in "${roots[@]}"; do
		if [ -d "$r" ]; then
			find "$r" -name '*.gd' -not -path '*/addons/*'
		else
			case "$r" in
				*/addons/*) ;;                 # skip explicit files under addons
				*) printf '%s\n' "$r" ;;
			esac
		fi
	done
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
			exec gdformat --line-length 160 "${files[@]}"
		fi
		# Dry-run: --check reports files that need formatting and exits non-zero; it never writes.
		gdformat --check --line-length 160 "${files[@]}"
		status=$?
		if [ "$status" -ne 0 ]; then
			echo "gdtoolkit.sh: apply with 'make format-write' (or 'make format-staged' for staged)." >&2
		fi
		exit "$status"
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
