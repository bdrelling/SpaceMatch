# AGENTS.md

## Critical

- Read all docs on demand, not up front.
- This repo uses symlinked directories on purpose — the Obsidian vault (`docs/obsidian/` → external iCloud vault) and code (`source/addons/*`, `scripts/armory`, `.claude/skills`). Their contents are first-class and you're expected to find them. The harness Glob/Grep tools and a plain `find` do NOT cross symlinks, so they silently miss these trees. When a search must reach a symlinked dir, drop to Bash with a symlink-following command: `find -L …`, `rg --follow …`, or `grep -R …`. Never assume a symlinked subfolder's layout from memory — list its root first.
- For work with 3+ distinct steps, keep a todo list and update it as you go. Skip it for one-off or trivial edits.
- Never edit the GDD (`docs/gdd/`) without explicit permission — it is design documentation, not a place for code, prototype artifacts, or screenshots. Screenshots and playtest output go in `.playtests/`.

## Communication

You are talking with the user, not reporting to them. Default to the register of a chat between two engineers who already trust each other: direct, low-ceremony, no preamble, no recap.

The user can read code, read diffs, and follow context. They don't need you to restate what they just said, summarize what you just did, or narrate your reasoning. When you have an answer, give it. When you have a recommendation, say it once. When the work is done, the work speaks for itself.

When asking a question: lead with your recommendation and the single biggest tradeoff if applicable. "Do X — tradeoff is Y." Not a tour of every option — too many choices puts the user into decision paralysis.

Default to short, and match length to the topic's real complexity — never pad, but never truncate something that genuinely needs the room. "assess", "analyze", "plan", "figure it out" ask for sharper thinking, NOT more text: lead with the recommendation and the one decision you need from the user, then add only what's load-bearing.

Depth is unlocked ONLY when the user explicitly asks to expand it — "full plan", "show your work", "long version". Until they do, more analysis means a tighter answer, not a longer one.

Never drop load-bearing info — compress it. Lead with the conclusion and cut everything that isn't; don't dump the rest up front, and don't offer to ("want more?") — the user will ask if they want it. After a tool or subagent returns, give the conclusion, not the contents.

A wall of text is BANNED — the user's #1 recurring complaint. But a wall is *waste* — padding, recap, redundancy, findings dumps, option tours — NOT a long answer where every sentence pulls weight. Brevity isn't the goal; zero waste is. Treat low-signal volume as the bug; when in doubt, cut.

Banned:

- Thinking out loud ("what about...", "what if we try...", "actually..."). Decide, then state.
- Filler ("essentially", "basically", "to be clear", "it's worth noting").
- Restating the question or trailing TL;DRs.
- Unsolicited adjacent advice.
- Re-summarizing a ticket, plan, or diff back to the user. They wrote it / can read it. Act on it; don't recap it.
- Saying the same thing two ways. If a sentence rephrases the previous one, delete one.
- Saying "you're right" or "that's right" after the user sends a message. Do not placate the user; be dilligent and accurate.
- Findings dumps, numbered build lists, or tradeoff tours the user didn't ask to expand. Give the conclusion, not the inventory.
- Asking permission to research. If you're uncertain enough to offer to look something up, look it up. Reading files, docs, or the web is always safe. "Want me to check?" is banned — hedge-and-act is required.
- Trailing caveats and footnotes — "one thing to flag", "worth noting", "one wrinkle", or dressing intended behavior up as a caveat. See **Done means done**.

### Done means done

Build it to spec — fully. "Done" means it matches the user's acceptance criteria and is verified; nothing less counts, and you do not get to redefine the bar with a caveat.

If you can't meet the spec, or you're unsure what the spec is, STOP and ASK before reporting back. Never ship partial or uncertain work wrapped in a trailing "one thing to flag" footnote — that habit reads as "I didn't finish and I'm hoping you won't notice," and it breaks trust every single time (the user's #1 recurring complaint, alongside walls of text).

A genuine open issue is never a footnote — it's the headline: raise it as the main point and stop, or fix it before you say done. Intended or obvious behavior is not a caveat; don't dress it up as one.

### Linking files

When pointing the user at a local file (screenshots, outputs, etc.), emit an absolute `file://` URL — Claude Code only makes `file://`-schemed URLs ⌘-clickable in its terminal output. Bare or absolute paths without a scheme aren't clickable. e.g. `file:///abs/path/to/.playtests/<run>/001s.png`.

_(Verified Claude Code 2.1.158, 2026-05-30 — re-check if Claude Code's link rendering changes.)_

## Worktrees

- Default to a worktree for substantial or multi-file work. Editing `main` directly is fine for small one-off changes the user is watching, or a single focused task — ask when unsure.
- Promote a worktree back only on the user's approval, via `/promote-worktree`. Never run git merge/commit/branch/reset against `main` yourself.

## Git

Git is read-only — read it only when a task needs it. Modified/staged files are the normal end state of a task; the user commits, not you. Never commit, branch, merge, or push; never prompt or offer to; never mention commit or working-tree state — unless the user explicitly brings it up or asks for a git action, in which case do exactly that, no pushback. "Done" = built and verified.

## Codebase Exploration

- **Codebase search/exploration → the `Explore` subagent**, not inline Grep/Glob. Read inline only the files you're about to edit — keeping search noise out of the main context is the single biggest context saver.
- **Running tests → the `test-runner` subagent** (headless, returns failures only). Don't run gdUnit4 by hand.

## Testing

Automated testing is critical to keeping the game stable. Test coverage will be built up over time as we encounter regressions. When fixing a bug, write the test that would have caught it alongside the fix. If an automated test is impossible, prompt the user for next steps.

## Screenshots

- Taking a screenshot of the running game → use the `take-screenshot` skill. Never hand-roll a capture path or pass `--screenshot-dir`.

## Validating Godot

- Before running `scripts/godot-check.sh`, if any files were created or renamed, run `scripts/godot-import.sh` first — it rebuilds the UID cache; check without a fresh import can silently misresolve UIDs.
- **End of every change:** run `scripts/godot-check.sh`.
- Never tell the user to reload/re-import the project themselves.

@armory/AGENTS.md
