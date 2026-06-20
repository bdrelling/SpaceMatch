#!/usr/bin/env bash
# Concatenate the Game Design Document into a single markdown stream on stdout.
# Reads docs/gdd/README.md to determine the canonical TOC ordering and
# inlines the content of every linked subsection file. Subsections whose file
# is missing or contains nothing beyond its `# Heading` line print as "TBD".
# Examples:
#   ./scripts/print_gdd.sh
#   ./scripts/print_gdd.sh > /tmp/gdd.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GDD_DIR="$SCRIPT_DIR/../docs/gdd"
README="$GDD_DIR/README.md"
TITLE="Rustworld"

if [[ ! -f "$README" ]]; then
    echo "print_gdd.sh: $README not found." >&2
    exit 1
fi

print_content() {
    local file="$1"
    if [[ ! -f "$file" || ! -s "$file" ]]; then
        echo "TBD"
        return
    fi
    local content
    content="$(awk '
        NR == 1 && /^# / { next }
        body || NF {
            body = 1
            if (/^#+ /) sub(/^#+/, "&##")
            print
        }
    ' "$file")"
    if [[ -z "$content" ]]; then
        echo "TBD"
    else
        printf '%s\n' "$content"
    fi
}

# Title block.
echo "# $TITLE Game Design Document"
echo
echo "Generated on $(date '+%B %-d, %Y at %-I:%M %p')"
echo
echo "## Table of Contents"
echo

# Pass 1: emit the TOC.
section_num=0
while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)\.\ (.+)$ ]]; then
        section_num="${BASH_REMATCH[1]}"
        rest="${BASH_REMATCH[2]}"
        if [[ "$rest" =~ ^\[(.+)\]\(.+\)$ ]]; then
            name="${BASH_REMATCH[1]}"
        else
            name="$rest"
        fi
        echo "${section_num}. ${name}"
    elif [[ "$line" =~ ^\ {4}([0-9]+)\.\ \[(.+)\]\(.+\)$ ]]; then
        sub_num="${BASH_REMATCH[1]}"
        title="${BASH_REMATCH[2]}"
        echo "   ${section_num}.${sub_num}. ${title}"
    fi
done < "$README"

# Pass 2: emit each section and subsection with content.
section_num=0
while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)\.\ (.+)$ ]]; then
        section_num="${BASH_REMATCH[1]}"
        rest="${BASH_REMATCH[2]}"
        if [[ "$rest" =~ ^\[(.+)\]\((.+)\)$ ]]; then
            name="${BASH_REMATCH[1]}"
            file="$GDD_DIR/${BASH_REMATCH[2]}"
            echo
            echo "## ${section_num}. ${name}"
            echo
            print_content "$file"
        else
            echo
            echo "## ${section_num}. ${rest}"
        fi
    elif [[ "$line" =~ ^\ {4}([0-9]+)\.\ \[(.+)\]\((.+)\)$ ]]; then
        sub_num="${BASH_REMATCH[1]}"
        title="${BASH_REMATCH[2]}"
        file="$GDD_DIR/${BASH_REMATCH[3]}"
        echo
        echo "### ${section_num}.${sub_num}. ${title}"
        echo
        print_content "$file"
    fi
done < "$README"
