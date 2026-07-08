# AGENTS.md

## Critical

- Read all docs on demand, not up front.
- This repo uses symlinked directories on purpose — the Obsidian vault (`docs/obsidian/` → external iCloud vault) and code (`source/addons/*`, `scripts/armory`, `.claude/skills`, `.claude/agents`). Their contents are first-class and you're expected to find them. The harness Glob/Grep tools and a plain `find` do NOT cross symlinks, so they silently miss these trees. When a search must reach a symlinked dir, drop to Bash with a symlink-following command: `find -L …`, `rg --follow …`, or `grep -R …`. Never assume a symlinked subfolder's layout from memory — list its root first. The skills tree is reachable as both `.agents/skills/…` and `.claude/skills/…` — these are the **same files** (`.claude/skills` symlinks to the real `.agents/skills`). Editing or `require()`-ing through either path is identical; this is settled, don't re-investigate it.
- For work with 3+ distinct steps, keep a todo task list and update it as you go. Skip it for one-off or trivial edits.
- Never edit the GDD (`docs/gdd/`) without explicit permission — it is design documentation, not a place for code, prototype artifacts, or screenshots. Screenshots and playtest output go in `.playtests/`.
- Mockups live in `mockups/<name>/` — self-contained HTML click-throughs. "Get a mockup in context" = read that dir's `README.md`; it IS the full brief. Don't render it (or read `index.html`) just to understand it. Details + the render path in `mockups/AGENTS.md`.
- Sometimes more than one LLM agent may be modifying files at once, but in different areas of the codebase. Don't freak out about this or event mention it. If you notice unrelated issues pop up in files you haven't touched or don't expect to be downstream dependencies, pause your work and try again a minute later. If it still has issues, pause and ask the user to let you know when the other agents have finished their work.
- **When your work is done, output the result and STOP.** Don't append a trailing flag, caveat, note, question, or next-step suggestion after it. See **Done means done**.
- If the user says you made or wrote something, take their word for it — don't argue. You don't carry context between conversations, so you very likely did create it in an earlier session you can no longer see. Accept it and move on.

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

### Done Means Done

Build it to spec — fully. "Done" means it matches the user's acceptance criteria and is verified; nothing less counts, and you don't get to redefine the bar with a caveat.

The last thing in a "done" message is the result or status itself. Deliver it and stop there — ending on the result is finished, not abrupt.

Don't append a trailing closer after the result, such as:

- "one thing to flag" / "one note" / "one wrinkle" / "worth noting"
- "one last decision" / "your call" / "one thing to circle back to"
- a trailing question or offer — "want me to…", "should I…", "let me know", "say the word", "if you want"
- a nudge toward a next step

That trailing closer is **hedging** — **leaving yourself an escape hatch** in case the work isn't right. Commit to the result and stop.

A genuine blocker or open issue is the headline, not a footer: raise it first — or instead of reporting done — and stop. Don't tack it on after the result. Intended or obvious behavior isn't a caveat; don't dress it up as one.

If you can't meet the spec, or you're unsure what it is, stop and ask before doing the work — not after, wrapped in a trailing note.

### Linking Files

When pointing the user at a local file (screenshots, outputs, etc.), emit an absolute `file://` URL — Claude Code only makes `file://`-schemed URLs ⌘-clickable in its terminal output. Bare or absolute paths without a scheme aren't clickable. e.g. `file:///abs/path/to/.playtests/<run>/001s.png`.

*(Verified Claude Code 2.1.158, 2026-05-30 — re-check if Claude Code's link rendering changes.)*

## Worktrees

- Default to a worktree only when the user tells you to use one. Editing `main` directly is fine for small one-off changes the user is watching, or a single focused task — ask when unsure.
- Promote a worktree back only on the user's approval, via `/promote-worktree`. Never run git merge/commit/branch/reset against `main` yourself.

## Git

Git is read-only — read it only when a task needs it. Modified/staged files are the normal end state of a task; the user commits, not you. Never commit, branch, merge, or push; never prompt or offer to; never mention commit or working-tree state — unless the user explicitly brings it up or asks for a git action, in which case do exactly that, no pushback. "Done" = built and verified.

## Codebase Exploration

- **Codebase search/exploration → the `Explore` subagent**, not inline Grep/Glob. Read inline only the files you're about to edit — keeping search noise out of the main context is the single biggest context saver.
- **Running tests → the `test-runner` subagent** (headless, returns failures only). Don't run gdUnit4 by hand.
- **Running Godot/gdtoolkit headless (check, import, lint, format, verify) → the `godot-runner` subagent** (returns only errors). Keeps project-wide tool output out of the main context, like `test-runner` does for tests.

## Testing

Automated testing is critical to keeping the game stable. Test coverage will be built up over time as we encounter regressions. When fixing a bug, write the test that would have caught it alongside the fix. If an automated test is impossible, prompt the user for next steps.

## Screenshots

- Taking a screenshot of the running game → use the `take-screenshot` skill. Never hand-roll a capture path or pass `--screenshot-dir`.

## Validating Godot

- Before running `make check` (`./scripts/armory check`), if any files were created or renamed, run `make import` first — it rebuilds the UID cache; check without a fresh import can silently misresolve UIDs.
- **End of every change:** run `make verify-staged` — full, every time. Don't stop at the parse check alone; that lets lint/test breaks through. Run `check`/`verify` via `godot-runner` and `test` via `test-runner`.
- Never tell the user to reload/re-import the project themselves.

## Linting & formatting (gdtoolkit)

`make verify-staged` is the gate: `lint-staged → format-staged → import → check → test` (staged scope), fail-fast — run it at the end of every change. `make verify` is the whole-`source/` version: `lint → format → import → check → test`. Also `make lint` / `make format` (whole `source/`, minus `addons/`; `format-write` applies) and their `-staged` variants; `ARGS="<files>"` scopes any of them. See `make help`. Installed via `make setup`.

Editing a `.gd` file auto-runs `gdformat` (source of truth) then `gdlint` on it and surfaces the conventions, via the PostToolUse/PreToolUse hooks in `.claude/`. Write to the conventions up front — member order is exactly what `gdlint` enforces, wrapped in `#region`s. Full guide: `armory/docs/languages/gdscript/` (README = the formatter → linter → guide layering).

@armory/AGENTS.md
