#!/bin/zsh

# Print the command we're running so that it can be run manually
replace_newlines_with_spaces() {
	echo "$1" | tr '\n\t' ' ' | sed 's/  */ /g' | sed 's/ 2>&1$//'
}

# Get the repository root directory.
# Falls back to the script's grandparent dir when not inside a git repo
# (e.g. running inside a fresh sandbox / CI container).
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="${0:A:h:h}"

# Get the path to the godot binary (PATH first, then the Docker fallback)
GODOT_BIN=$("$REPO_ROOT/scripts/godot-bin.sh")

# Test targets come from the args ("$@") — dirs or files. No args = auto-discovered suites.

# We need to step into the source directory to run the test runner
cd "$REPO_ROOT/source"

# Get the path to the gdUnit4 test runner
GDUNIT4_TEST_RUNNER="./addons/gdUnit4/runtest.sh"

# Build the --add flags for the test runner.
# With no argument, scan only the directories that contain test suites — never
# pass --add . — because a whole-project scan force-loads every script and
# scene in the project (addons included), which:
#   - aborts discovery: gdUnit4's bundled test resources declare a `Player`
#     class that hides our global Player class (exit 105)
#   - misresolves scene->script ext_resources mid-scan, producing false
#     "non-existent resource" test errors in suites that instantiate scenes
#   - crashes the macOS headless backend at exit with SIGABRT (engine bug:
#     leaked GDScript objects torn down after script-language cleanup;
#     see godotengine/godot#95174 / #98182)
if [ "$#" -gt 0 ]; then
	ADD_FLAGS=""
	for _target in "$@"; do
		ADD_FLAGS="$ADD_FLAGS --add \"$_target\""
	done
else
	ADD_FLAGS=$(grep -rl --include='test_*.gd' --exclude-dir=addons 'extends GdUnitTestSuite' . \
		| xargs -n1 dirname | sed 's|^\./||' | sort -u | sed 's/^/--add /' | tr '\n' ' ')
fi

# Headless decision, in priority order:
#   1. CI=true ALWAYS forces headless (CI machines have no display).
#   2. otherwise HEADLESS is honored, and it DEFAULTS to true — tests never need
#      a window. Set HEADLESS=false to watch a windowed run (and get the HTML
#      report popped open at the end; see below).
# When headless we also tell gdUnit4 to skip its display-required guard.
HEADLESS="${HEADLESS:-true}"
[ "$CI" = "true" ] && HEADLESS=true
HEADLESS_FLAGS=""
if [ "$HEADLESS" = "true" ]; then
	HEADLESS_FLAGS="--headless --ignoreHeadlessMode"
fi

# Run the gdUnit4 test runner from the repo root
# Report directory needs to be relative to the source directory
# Searches for tests in the specified directory
BASE_COMMAND="$GDUNIT4_TEST_RUNNER \
	--godot_binary \"$GODOT_BIN\" \
	--report-directory \"../reports\" \
	$ADD_FLAGS \
    --continue \
    --verbose \
    $HEADLESS_FLAGS \
	2>&1"

echo "=========================================="
echo "Running Command:"
echo "$ cd source && $(replace_newlines_with_spaces "$BASE_COMMAND")"
echo "=========================================="

if [ "$DEBUG" = "true" ]; then
	# Show output while running and capture it
	TEST_OUTPUT=$(eval "$BASE_COMMAND" | tee /dev/tty)
else
	# Capture output silently
	TEST_OUTPUT=$(eval "$BASE_COMMAND")
fi

EXIT_CODE=$?

# Set the reports directory
REPORTS_DIRECTORY="$REPO_ROOT/reports"

# Parse the output to extract key information
# Get the last few lines and parse them
# Strip ANSI color codes so the parsing below sees plain text — gdUnit embeds
# resets mid-line (e.g. between "Overall Summary:" and its value).
TEST_OUTPUT=$(echo "$TEST_OUTPUT" | sed $'s/\033\\[[0-9;]*m//g')

# Parse the full output — headless runs print an unbounded amount of leak
# noise after the summary, so a fixed tail window can miss it entirely.
LAST_LINES="$TEST_OUTPUT"

# Extract overall summary
OVERALL_SUMMARY=$(echo "$LAST_LINES" | grep "Overall Summary:" | sed 's/.*Overall Summary: //' | sed 's/|$//')

# Extract test counts from summary
TOTAL_TESTS=$(echo "$OVERALL_SUMMARY" | grep -o "[0-9]* test cases" | grep -o "[0-9]*")
ERRORS=$(echo "$OVERALL_SUMMARY" | grep -o "[0-9]* errors" | grep -o "[0-9]*")
FAILURES=$(echo "$OVERALL_SUMMARY" | grep -o "[0-9]* failures" | grep -o "[0-9]*")
FLAKY=$(echo "$OVERALL_SUMMARY" | grep -o "[0-9]* flaky" | grep -o "[0-9]*")
SKIPPED=$(echo "$OVERALL_SUMMARY" | grep -o "[0-9]* skipped" | grep -o "[0-9]*")
ORPHANS=$(echo "$OVERALL_SUMMARY" | grep -o "[0-9]* orphans" | grep -o "[0-9]*")

# Extract execution summary
EXECUTED_SUITES=$(echo "$LAST_LINES" | grep -o "Executed test suites: ([0-9]*/[0-9]*)" | sed 's/Executed test suites: //')
EXECUTED_CASES=$(echo "$LAST_LINES" | grep -o "Executed test cases : ([0-9]*/[0-9]*)" | sed 's/Executed test cases : //')

# Extract execution time
TOTAL_EXECUTION_TIME=$(echo "$LAST_LINES" | grep -o "Total execution time: [^$]*" | sed 's/Total execution time: //')

# Extract XML report path
XML_REPORT_PATH=$(echo "$LAST_LINES" | grep -o "file://[^[:space:]]*results\.xml" | sed 's/file:\/\///')
XML_REPORT_PATH=$(realpath "$XML_REPORT_PATH" 2>/dev/null || echo "$XML_REPORT_PATH")

# Extract HTML report path  
HTML_REPORT_PATH=$(echo "$LAST_LINES" | grep -o "file://[^[:space:]]*index\.html" | sed 's/file:\/\///')
HTML_REPORT_PATH=$(realpath "$HTML_REPORT_PATH" 2>/dev/null || echo "$HTML_REPORT_PATH")

# Extract exit code
EXIT_CODE_FROM_OUTPUT=$(echo "$LAST_LINES" | grep -o "Exit code: [0-9]*" | sed 's/Exit code: //')

# --- Authoritative verdict from the report on disk ---------------------------
# gdUnit writes the full XML report when the run finishes, BEFORE Godot's engine
# teardown. On macOS headless that teardown intermittently SIGSEGVs while freeing
# leaked GDScript objects (engine bug godot#95174 / #98182), corrupting the
# *process* exit code (134/139) even though every test ran and the report is
# complete. So the verdict comes from results.xml, not the exit code.
RESULTS_XML=$(ls -dt "$REPORTS_DIRECTORY"/report_*/results.xml 2>/dev/null | head -1)
if [ -n "$RESULTS_XML" ] && [ -f "$RESULTS_XML" ]; then
	_root=$(grep -m1 "<testsuites " "$RESULTS_XML")
	TOTAL_TESTS=$(printf '%s' "$_root" | grep -oE 'tests="[0-9]+"' | grep -oE '[0-9]+')
	FAILURES=$(printf '%s' "$_root" | grep -oE 'failures="[0-9]+"' | grep -oE '[0-9]+')
	ERRORS=$(printf '%s' "$_root" | grep -oE 'errors="[0-9]+"' | grep -oE '[0-9]+')
	SKIPPED=$(printf '%s' "$_root" | grep -oE 'skipped="[0-9]+"' | grep -oE '[0-9]+')
	XML_REPORT_PATH="$RESULTS_XML"
	HTML_REPORT_PATH="${RESULTS_XML%results.xml}index.html"
	: "${TOTAL_TESTS:=0}"; : "${FAILURES:=0}"; : "${ERRORS:=0}"
	if [ "$FAILURES" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then VERDICT=1; else VERDICT=0; fi
	if [ "$EXIT_CODE" -gt 128 ]; then
		echo "NOTE: Godot crashed at engine teardown (exit $EXIT_CODE) — known macOS"
		echo "      headless bug. All $TOTAL_TESTS tests ran; verdict read from the report."
	fi
else
	echo "ERROR: no results.xml found — the run did not produce a report."
	VERDICT=$EXIT_CODE
fi

# Print a plain-language summary a human can read at a glance — no exit-code jargon.
FAILED_COUNT=$(( ${FAILURES:-0} + ${ERRORS:-0} ))
echo ""
echo "=================================================================="
if [ "${VERDICT:-1}" -eq 0 ]; then
	echo "✓  ALL TESTS PASSED — ${TOTAL_TESTS:-0} tests${TOTAL_EXECUTION_TIME:+ in $TOTAL_EXECUTION_TIME}"
else
	echo "✗  TESTS FAILED — $FAILED_COUNT of ${TOTAL_TESTS:-0} tests failed:"
	echo ""
	# Name each failing test, with its message and location, straight from the report.
	[ -f "$RESULTS_XML" ] && awk '
		/<testcase / { if (match($0, /name="[^"]*"/)) name=substr($0, RSTART+6, RLENGTH-7) }
		/<failure message=/ {
			where=""; if (match($0, /FAILED: [^"]*/)) where=substr($0, RSTART+8, RLENGTH-8)
			grab=1; next
		}
		grab && /CDATA/ { next }
		grab && NF {
			sub(/^[ \t]+/, "")
			print "  ✗ " name
			print "      " $0
			print "      → " where
			print ""
			grab=0
		}
	' "$RESULTS_XML"
fi
echo "------------------------------------------------------------------"
[ "${SKIPPED:-0}" -gt 0 ] && echo "($SKIPPED skipped)"
echo "Full report: $HTML_REPORT_PATH"
echo "=================================================================="

# Open the HTML report in the default browser only on a deliberate windowed run
# (HEADLESS=false) — the "I'm watching this" mode. Default headless / CI / agent
# runs never pop it.
if [ "$HEADLESS" != "true" ] && command -v open >/dev/null 2>&1; then
	open "$HTML_REPORT_PATH"
fi

# Exit with the report-derived verdict (falls back to the process code only when
# no report was produced).
exit ${VERDICT:-$EXIT_CODE}