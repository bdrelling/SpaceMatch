#!/usr/bin/env bash
# Run the game with automatic screenshot capture.
# On Linux, wraps Godot in Xvfb for headless rendering.
# On macOS, runs Godot natively.
#
# Examples:
#   ./scripts/playtest.sh --quit-after 30
#   ./scripts/playtest.sh --quit-after 60 -- --screenshot-interval=5
#   ./scripts/playtest.sh -- --screenshot-interval=2 --screenshot-delay=3 --screenshot-duration=10

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR/.."
PLAYTESTS_DIR="$(cd "$REPO_DIR" && pwd)/.playtests"

ENGINE_ARGS=()
USER_ARGS=()
SEEN_SEPARATOR=false
HAS_INTERVAL=false
HAS_DURATION=false
HAS_DELAY=false
HAS_DIR=false

for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
        SEEN_SEPARATOR=true
        continue
    fi
    if $SEEN_SEPARATOR; then
        USER_ARGS+=("$arg")
        [[ "$arg" == --screenshot-interval=* ]] && HAS_INTERVAL=true
        [[ "$arg" == --screenshot-duration=* ]] && HAS_DURATION=true
        [[ "$arg" == --screenshot-delay=* ]] && HAS_DELAY=true
        [[ "$arg" == --screenshot-dir=* ]] && HAS_DIR=true
    else
        ENGINE_ARGS+=("$arg")
    fi
done

$HAS_INTERVAL || USER_ARGS+=("--screenshot-interval=${SCREENSHOT_INTERVAL:-1}")
$HAS_DURATION || USER_ARGS+=("--screenshot-duration=${SCREENSHOT_DURATION:-1}")
$HAS_DELAY    || USER_ARGS+=("--screenshot-delay=${SCREENSHOT_DELAY:-0}")
$HAS_DIR      || USER_ARGS+=("--screenshot-dir=${SCREENSHOT_DIR:-$PLAYTESTS_DIR}")

if [[ "$(uname)" == "Linux" ]]; then
    cleanup() {
        if [[ -n "${XVFB_PID:-}" ]]; then
            kill "$XVFB_PID" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT

    Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX &
    XVFB_PID=$!
    sleep 1

    DISPLAY=:99 "$SCRIPT_DIR/play.sh" --rendering-driver opengl3 --audio-driver Dummy "${ENGINE_ARGS[@]}" -- "${USER_ARGS[@]}"
else
    "$SCRIPT_DIR/play.sh" --audio-driver Dummy "${ENGINE_ARGS[@]}" -- "${USER_ARGS[@]}"
fi
