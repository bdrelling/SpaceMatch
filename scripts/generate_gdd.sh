#!/usr/bin/env bash
# Generate the Game Design Document from the numbered files under docs/gdd/.
#
# Ordering is encoded in the filenames: every section directory and subsection
# file carries an "N-" prefix (1-concept/, 1-concept/1-overview.md, ...). The
# numbers ARE the manifest -- there is no separate config. Entries without a
# numeric prefix (setting.md, this script's own output) are ignored, and the
# tree may nest arbitrarily deep (e.g. 3-gameplay/11-minigames/1-ship-repair.md).
#
# Writes two files into docs/gdd/:
#   README.md                the table of contents (landing page): links out to
#                            each source file.
#   game-design-document.md  the whole document inline: an anchor-link TOC
#                            followed by every section's content. Section titles
#                            come from the directory name; subsection titles come
#                            from each file's `# Heading`. Empty files (heading
#                            only) render as "TBD".
#
# Usage:
#   ./scripts/generate_gdd.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GDD_DIR="$(cd "$SCRIPT_DIR/../docs/gdd" && pwd)"
TITLE="${GAME_NAME:-MyGame}"
GENERATED_ON="$(date '+%B %-d, %Y at %-I:%M %p')"

README="$GDD_DIR/README.md"                      # table of contents (landing page)
FULLDOC="$GDD_DIR/game-design-document.md"       # entire document, one page

# Scratch streams assembled during the walk.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gdd.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
TOC_FILES="$TMP/toc_files"   # README:  links to source files
TOC_ANCH="$TMP/toc_anchors"  # fulldoc: links to inline anchors
BODY="$TMP/body"             # fulldoc: inline content
: >"$TOC_FILES" >"$TOC_ANCH" >"$BODY"

repeat() { local c="$1" n="$2" out=''; while ((n-- > 0)); do out+="$c"; done; printf '%s' "$out"; }

# "5-core-mechanics" / "5-core-mechanics.md" -> "Core Mechanics".
# Capitalizes each word, but keeps small words (and, of, ...) lowercase mid-title.
titleize() {
    local raw="${1%.md}"; raw="${raw#*-}"           # drop number prefix
    awk -v s="$raw" 'BEGIN {
        ns = split("and or nor but the a an of to in on at by for with vs", small, " ")
        n = split(s, w, "-")
        for (i = 1; i <= n; i++) {
            lw = tolower(w[i]); is = 0
            for (j = 1; j <= ns; j++) if (small[j] == lw) { is = 1; break }
            tok = (i > 1 && is) ? lw : toupper(substr(lw, 1, 1)) substr(lw, 2)
            printf "%s%s", (i > 1 ? " " : ""), tok
        }
    }'
}

# First `# Heading` of a file, else a title derived from its name.
file_title() {
    local h
    h="$(awk 'NR==1 && sub(/^#[[:space:]]+/, "") { print; exit }' "$1")"
    [[ -n "$h" ]] && { printf '%s' "$h"; return; }
    titleize "$(basename "$1")"
}

# GitHub-compatible heading anchor.
slugify() {
    awk -v s="$1" 'BEGIN {
        s = tolower(s); gsub(/[^a-z0-9 _-]/, "", s); gsub(/ /, "-", s); printf "%s", s
    }'
}

# Inline a file's body: strip its `# Heading`, drop standalone HTML comments,
# demote inner headings to sit beneath the subsection, "TBD" when empty.
emit_content() {
    local file="$1" demote; demote="$(repeat '#' $(( $2 - 1 )))"
    [[ -s "$file" ]] || { echo TBD; return; }
    local content
    content="$(awk -v d="$demote" '
        NR == 1 && /^# / { next }
        /^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }
        body || NF { body = 1; if (/^#+ /) sub(/^#+/, d "&"); print }
    ' "$file")"
    [[ -n "$content" ]] && printf '%s\n' "$content" || echo TBD
}

# List a dir's numbered children (files and dirs), sorted by their number.
numbered_children() {
    local d="$1" e b
    for e in "$d"/[0-9]*-*; do
        [[ -e "$e" ]] || continue
        b="$(basename "$e")"
        printf '%s\t%s\n' "${b%%-*}" "$e"
    done | sort -n -k1,1 | cut -f2-
}

# Recurse the tree, appending to the three streams.
#   $1 dir   $2 number prefix ("" | "3." | "3.11.")   $3 depth (0-based)
walk() {
    local dir="$1" prefix="$2" depth="$3" entry name num secnum title indent level
    indent="$(repeat ' ' $((depth * 4)))"
    level=$((depth + 2))                              # heading level: ## at top
    while IFS= read -r entry; do
        name="$(basename "$entry")"
        num="${name%%-*}"
        secnum="${prefix}${num}"
        if [[ -d "$entry" ]]; then
            title="$(titleize "$name")"
            printf '%s%s. %s\n'        "$indent" "$num" "$title"                                >>"$TOC_FILES"
            printf '%s%s. [%s](#%s)\n' "$indent" "$num" "$title" "$(slugify "$secnum. $title")" >>"$TOC_ANCH"
            printf '\n%s %s. %s\n'     "$(repeat '#' "$level")" "$secnum" "$title"              >>"$BODY"
            walk "$entry" "${secnum}." $((depth + 1))
        else
            [[ "$name" == *.md ]] || continue
            title="$(file_title "$entry")"
            printf '%s%s. [%s](%s)\n'  "$indent" "$num" "$title" "${entry#$GDD_DIR/}"           >>"$TOC_FILES"
            printf '%s%s. [%s](#%s)\n' "$indent" "$num" "$title" "$(slugify "$secnum. $title")" >>"$TOC_ANCH"
            printf '\n%s %s. %s\n\n'   "$(repeat '#' "$level")" "$secnum" "$title"              >>"$BODY"
            emit_content "$entry" "$level" >>"$BODY"
        fi
    done < <(numbered_children "$dir")
}

walk "$GDD_DIR" "" 0

# --- README.md: the table of contents, linking out to each source file ---
{
    printf '# %s Game Design Document — Table of Contents\n\n' "$TITLE"
    printf '_Generated on %s._\n\n' "$GENERATED_ON"
    printf '_For the full document, see [game-design-document.md](game-design-document.md)._\n\n'
    cat "$TOC_FILES"
} >"$README"

# --- game-design-document.md: the entire document on one page ---
{
    printf '# %s Game Design Document\n\n' "$TITLE"
    printf '_Generated on %s._\n\n' "$GENERATED_ON"
    printf '<!-- Do not edit by hand — run scripts/generate_gdd.sh -->\n\n'
    printf '## Table of Contents\n\n'
    cat "$TOC_ANCH"
    cat "$BODY"
} >"$FULLDOC"

echo "Wrote ${README#$GDD_DIR/../} and ${FULLDOC#$GDD_DIR/../}" >&2
