#!/usr/bin/env bash
# Interactive terminal walkthrough of the Game Design Document.
# Reads docs/gdd/README.md for ordering and presents each subsection one at a
# time. Actions: back, next, edit, request changes, quit. Edit drops into an
# inline note buffer (Ctrl+D saves, Ctrl+C cancels) whose contents persist for
# the session. Request changes bundles all notes and hands them to the `claude`
# CLI from within docs/gdd, instructing it to limit edits to that directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GDD_DIR="$SCRIPT_DIR/../docs/gdd"
README="$GDD_DIR/README.md"

if [[ ! -f "$README" ]]; then
    echo "review_gdd.sh: $README not found. Run scripts/generate_gdd.sh first." >&2
    exit 1
fi

# Build flat section list. Each entry is "section_num|sub_num|section_name|sub_title|file".
# sub_num and sub_title are empty for top-level sections that link directly to a file
# (e.g. Glossary).
SECTIONS=()
current_section_num=""
current_section_name=""

while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)\.[[:space:]]\[(.+)\]\((.+)\)$ ]]; then
        SECTIONS+=("${BASH_REMATCH[1]}||${BASH_REMATCH[2]}||${BASH_REMATCH[3]}")
    elif [[ "$line" =~ ^([0-9]+)\.[[:space:]](.+)$ ]]; then
        current_section_num="${BASH_REMATCH[1]}"
        current_section_name="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^[[:space:]]{4}([0-9]+)\.[[:space:]]\[(.+)\]\((.+)\)$ ]]; then
        SECTIONS+=("${current_section_num}|${BASH_REMATCH[1]}|${current_section_name}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}")
    fi
done < "$README"

total=${#SECTIONS[@]}
if (( total == 0 )); then
    echo "review_gdd.sh: no sections parsed from $README." >&2
    exit 1
fi

# Per-section notes captured during this review session, keyed by section index.
NOTES=()

# Alternate-screen mode: gives us a private buffer so each frame replaces the
# previous one in place, instead of stacking up in the terminal's scrollback.
enter_alt_screen() { printf '\033[?1049h\033[H'; }
leave_alt_screen() { printf '\033[?1049l'; }
home_clear() { printf '\033[H\033[2J'; }

cleanup() { leave_alt_screen; }
trap cleanup EXIT
enter_alt_screen

extract_prompt() {
    # Echo the first HTML comment's inner text (whitespace-trimmed). Supports
    # multi-line comments. Empty output if there isn't one.
    local file="$1"
    awk '
        /<!--/ {
            sub(/^.*<!--[[:space:]]*/, "")
            collecting = 1
        }
        collecting {
            if (match($0, /-->/)) {
                sub(/[[:space:]]*-->.*/, "")
                print
                exit
            }
            print
        }
    ' "$file"
}

extract_body() {
    # Echo everything except the leading `# Heading` line and any HTML comments.
    local file="$1"
    awk '
        NR == 1 && /^# / { next }
        {
            line = $0
            while (match(line, /<!--/)) {
                before = substr(line, 1, RSTART - 1)
                rest = substr(line, RSTART + RLENGTH)
                if (match(rest, /-->/)) {
                    line = before substr(rest, RSTART + RLENGTH)
                } else {
                    line = before
                    in_comment = 1
                    break
                }
            }
            if (in_comment) {
                if (match($0, /-->/)) {
                    in_comment = 0
                    line = substr($0, RSTART + RLENGTH)
                } else {
                    next
                }
            }
            print line
        }
    ' "$file"
}

term_cols() {
    local cols=""
    # stty reads from the controlling terminal even when stdout is piped.
    if [[ -r /dev/tty ]]; then
        cols="$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')"
    fi
    if [[ -z "$cols" || ! "$cols" =~ ^[0-9]+$ ]]; then
        cols="$(tput cols 2>/dev/null || true)"
    fi
    if [[ -z "$cols" || ! "$cols" =~ ^[0-9]+$ ]]; then
        cols="${COLUMNS:-80}"
    fi
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
    (( cols < 20 )) && cols=20
    echo "$cols"
}

repeat_char() {
    local char="$1" count="$2"
    (( count <= 0 )) && return
    printf '%*s' "$count" '' | tr ' ' "$char"
}

print_bar() {
    local width="$1"
    repeat_char '=' "$width"
    printf '\n'
}

print_progress() {
    local current="$1" total="$2" width="$3"
    local filled=$(( current * width / total ))
    (( filled > width )) && filled=$width
    local empty=$(( width - filled ))
    repeat_char '#' "$filled"
    repeat_char '-' "$empty"
    printf '\n'
}

# ANSI styles. Disabled if stdout is not a tty.
if [[ -t 1 ]]; then
    A_BOLD=$'\033[1m'
    A_ITALIC=$'\033[3m'
    A_DIM=$'\033[2m'
    A_RESET=$'\033[0m'
else
    A_BOLD=""; A_ITALIC=""; A_DIM=""; A_RESET=""
fi

render() {
    local idx="$1"
    IFS='|' read -r section_num sub_num section_name sub_title file <<< "${SECTIONS[$idx]}"
    local full_path="$GDD_DIR/$file"
    local cols
    cols="$(term_cols)"

    home_clear
    print_bar "$cols"
    local title plain counter pad
    if [[ -n "$sub_num" ]]; then
        title="$(printf '%s.%s. %s%s%s - %s%s%s' \
            "$section_num" "$sub_num" \
            "$A_ITALIC" "$section_name" "$A_RESET" \
            "$A_BOLD" "$sub_title" "$A_RESET")"
        plain="$(printf '%s.%s. %s - %s' "$section_num" "$sub_num" "$section_name" "$sub_title")"
    else
        title="$(printf '%s. %s%s%s' "$section_num" "$A_ITALIC" "$section_name" "$A_RESET")"
        plain="$(printf '%s. %s' "$section_num" "$section_name")"
    fi
    counter="$(printf '%d / %d' $((idx + 1)) "$total")"
    pad=$(( cols - ${#plain} - ${#counter} ))
    (( pad < 1 )) && pad=1
    printf '%s%*s%s\n' "$title" "$pad" '' "$counter"
    print_bar "$cols"
    printf '\n'

    local prompt="" body=""
    if [[ -f "$full_path" ]]; then
        prompt="$(extract_prompt "$full_path")"
        body="$(extract_body "$full_path")"
    fi

    if [[ -n "$prompt" ]]; then
        local prompt_width=$(( cols - 3 ))
        (( prompt_width < 10 )) && prompt_width=10
        while IFS= read -r pline; do
            if [[ -z "$pline" ]]; then
                printf '%s//%s\n' "$A_DIM" "$A_RESET"
            else
                while IFS= read -r wrapped; do
                    printf '%s// %s%s\n' "$A_DIM" "$wrapped" "$A_RESET"
                done < <(printf '%s\n' "$pline" | fold -s -w "$prompt_width")
            fi
        done <<< "$prompt"
        printf '\n'
    fi

    # Strip leading/trailing blank lines from body so the layout stays tight.
    body="$(printf '%s' "$body" | awk '
        { lines[NR] = $0 }
        END {
            start = 1; end = NR
            while (start <= end && lines[start] ~ /^[[:space:]]*$/) start++
            while (end >= start && lines[end] ~ /^[[:space:]]*$/) end--
            for (i = start; i <= end; i++) print lines[i]
        }
    ')"

    if [[ -n "$body" ]]; then
        printf '%s\n' "$body" | fold -s -w "$cols"
    else
        printf '%s(empty — nothing written yet)%s\n' "$A_ITALIC" "$A_RESET"
    fi

    local note="${NOTES[$idx]:-}"
    if [[ -n "$note" ]]; then
        printf '\n'
        printf '%sNOTE:%s\n' "$A_BOLD" "$A_RESET"
        printf '%s\n' "$note" | fold -s -w "$cols"
    fi

    printf '\n'
    print_bar "$cols"
    printf '[b]ack  [n]ext  [e]dit  [r]equest changes  [q]uit\n'
    print_bar "$cols"
    printf '\n'
}

edit_note() {
    local idx="$1"
    local cols
    cols="$(term_cols)"

    # Suspend the resize handler — line editing shouldn't be redrawn underfoot.
    trap - WINCH

    render "$idx"
    print_bar "$cols"
    printf '%snote — type below. Ctrl+D saves. Ctrl+C cancels. Empty input keeps the existing note.%s\n' \
        "$A_DIM" "$A_RESET"
    print_bar "$cols"
    printf '\n'

    local new cancelled=0
    trap 'cancelled=1' INT
    new="$(cat || true)"
    trap - INT
    trap 'render "$idx"' WINCH

    (( cancelled )) && return
    [[ -n "$new" ]] && NOTES[$idx]="$new"
}

request_changes() {
    local i count=0
    for i in "${!NOTES[@]}"; do
        [[ -n "${NOTES[$i]}" ]] && count=$((count + 1))
    done

    local cols
    cols="$(term_cols)"

    if (( count == 0 )); then
        home_clear
        printf 'No notes to submit. Press any key to continue.\n'
        IFS= read -rsn1 _ || true
        return
    fi

    if ! command -v claude >/dev/null 2>&1; then
        home_clear
        printf 'claude CLI not found in PATH. Press any key to continue.\n'
        IFS= read -rsn1 _ || true
        return
    fi

    local prompt
    prompt=$'I am reviewing the Game Design Document and have notes on the sections below. '
    prompt+=$'Apply each note as edits to the listed file. Files are paths relative to the '
    prompt+=$'current working directory; only modify files inside this directory.\n\n'

    local snum subnum sname stitle file heading
    for i in "${!SECTIONS[@]}"; do
        if [[ -n "${NOTES[$i]:-}" ]]; then
            IFS='|' read -r snum subnum sname stitle file <<< "${SECTIONS[$i]}"
            if [[ -n "$subnum" ]]; then
                heading="${snum}.${subnum}. ${sname} - ${stitle}"
            else
                heading="${snum}. ${sname}"
            fi
            prompt+="## ${heading}"$'\n'
            prompt+="File: ${file}"$'\n'
            prompt+=$'Note:\n'
            prompt+="${NOTES[$i]}"$'\n\n'
        fi
    done

    home_clear
    trap - WINCH
    # Leave alt screen so claude renders in the user's normal terminal.
    leave_alt_screen
    trap - EXIT
    cd "$GDD_DIR" || exit 1
    exec claude "$prompt"
}

idx=0
trap 'render "$idx"' WINCH

render "$idx"
while true; do
    if ! IFS= read -rsn1 key; then
        # Interrupted by signal (e.g. SIGWINCH). The trap handler already
        # redrew, so just wait for the next key.
        continue
    fi
    case "$key" in
        b|B) idx=$(( (idx - 1 + total) % total )); render "$idx" ;;
        n|N) idx=$(( (idx + 1) % total )); render "$idx" ;;
        e|E) edit_note "$idx"; render "$idx" ;;
        r|R) request_changes; render "$idx" ;;
        q|Q) exit 0 ;;
    esac
done
