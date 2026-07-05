#!/usr/bin/env bash
# Render a mockup screen to PNG. This is the ONLY supported way to render a
# mockup — don't improvise a `chromium`/`google-chrome` invocation, it resolves
# whatever headless browser exists and fails cleanly when none does.
#
# Usage:
#   mockups/render.sh <mockup-dir> [screen-id] [scroll-px] [out.png]
#
#   mockups/render.sh debug-menu               # home screen (index.html as-is)
#   mockups/render.sh debug-menu ed_status     # a specific SCREENS id
#   mockups/render.sh debug-menu ed_status 240 # ...scrolled 240px
#
# Screen ids come from the `SCREENS` registry in that dir's index.html.
# Omit the screen (or pass `home`) to capture the true initial state — routing
# `home` through screenshot.html pushes a stray back link (see the README).
#
# Exit 3 = no headless browser (normal in cloud/CI containers). That is NOT a
# failure to fix: the mockup's README fully describes the design, so reading it
# is always enough for context. Only render when a human needs an actual image.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dir="${1:?usage: render.sh <mockup-dir> [screen-id] [scroll-px] [out.png]}"
screen="${2:-}"
scroll="${3:-0}"

[ -d "$here/$dir" ] || { echo "No such mockup: $dir (looked in $here)" >&2; exit 2; }

resolve_browser() {
  # Newest cached puppeteer chrome-headless-shell (version dir changes on update).
  local c
  c=$(ls -d "$HOME"/.cache/puppeteer/chrome-headless-shell/*/chrome-headless-shell-*/chrome-headless-shell 2>/dev/null | sort -V | tail -1 || true)
  [ -n "$c" ] && { printf '%s\n' "$c"; return 0; }
  # Anything on PATH.
  local b
  for b in chrome-headless-shell google-chrome-stable google-chrome chromium chromium-browser; do
    command -v "$b" >/dev/null 2>&1 && { command -v "$b"; return 0; }
  done
  # macOS app bundle.
  local app="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  [ -x "$app" ] && { printf '%s\n' "$app"; return 0; }
  return 1
}

browser="$(resolve_browser)" || {
  echo "No headless Chromium found (normal in cloud/CI containers)." >&2
  echo "Skip rendering — mockups/$dir/README.md fully describes the design." >&2
  exit 3
}

if [ -z "$screen" ] || [ "$screen" = home ]; then
  url="file://$here/$dir/index.html"                       # true initial state
  out="${4:-$here/$dir/render-home.png}"
else
  url="file://$here/$dir/screenshot.html?screen=$screen&scroll=$scroll"
  out="${4:-$here/$dir/render-$screen.png}"
fi

"$browser" --headless --disable-gpu --allow-file-access-from-files --hide-scrollbars \
  --screenshot="$out" --window-size="${WINDOW:-470,910}" --virtual-time-budget=4000 \
  "$url"
printf '%s\n' "$out"
