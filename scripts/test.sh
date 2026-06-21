#!/bin/zsh

# Print the command we're running so that it can be run manually
replace_newlines_with_spaces() {
	echo "$1" | tr '\n\t' ' ' | sed 's/  */ /g' | sed 's/ 2>&1$//'
}

# Get the repository root directory.
# Falls back to the script's grandparent dir when not inside a git repo
# (e.g. running inside a fresh sandbox / CI container).
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || REPO_ROOT="${0:A:h:h}"

# Get the path to the godot binary
GODOT_BIN=$(which godot)

# Get the test directory from the first argument
TEST_DIRECTORY=${1:-}

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
if [ -n "$TEST_DIRECTORY" ]; then
	ADD_FLAGS="--add \"$TEST_DIRECTORY\""
else
	ADD_FLAGS=$(grep -rl --include='test_*.gd' --exclude-dir=addons 'extends GdUnitTestSuite' . \
		| xargs -n1 dirname | sed 's|^\./||' | sort -u | sed 's/^/--add /' | tr '\n' ' ')
fi

# Headless decision, in priority order:
#   1. CI=true ALWAYS forces headless (CI machines have no display) — wins even
#      over an explicit HEADLESS=false.
#   2. otherwise HEADLESS is honored (true → headless, false → windowed).
#   3. default is windowed (false) — i.e. a human running it at their desk, who
#      also gets the HTML report popped open at the end (see below).
# When headless we also tell gdUnit4 to skip its display-required guard.
HEADLESS_FLAGS=""
if [ "$CI" = "true" ] || [ "$HEADLESS" = "true" ]; then
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

# Print summary
echo "====== SUMMARY ======"
echo "Overall summary: $OVERALL_SUMMARY"
echo "Total tests: $TOTAL_TESTS"
echo "Errors: $ERRORS"
echo "Failures: $FAILURES"
echo "Flaky: $FLAKY"
echo "Skipped: $SKIPPED"
echo "Orphans: $ORPHANS"
echo "Executed test suites: $EXECUTED_SUITES"
echo "Executed test cases: $EXECUTED_CASES"
echo "Total execution time: $TOTAL_EXECUTION_TIME"

echo "XML report path: $XML_REPORT_PATH"
echo "HTML report path: $HTML_REPORT_PATH"

echo "Exit code from output: $EXIT_CODE_FROM_OUTPUT"
echo "Actual exit code: $EXIT_CODE"

# Open the HTML report in the default browser (only on hosts that have `open`,
# and only for interactive runs — not CI, not explicit headless).
if [ -z "$CI" ] && [ "$HEADLESS" != "true" ] && command -v open >/dev/null 2>&1; then
	open "$HTML_REPORT_PATH"
fi

# Exit with the appropriate code for CI
exit $EXIT_CODE