---
name: obsidian
description: Orient in this repo's Obsidian vault — where notes/config/drawings live, and how to use the `obsidian` CLI for vault-aware ops (search, daily notes, tasks, tags, eval against the app API, plugin/dev work). Use when working with anything under docs/obsidian, or when a task needs Obsidian features (dataview, templates, cross-vault search) rather than a plain file edit.
---

# obsidian

The vault is `docs/obsidian/`. Notes are plain Markdown — **to read or edit a note, just use Read/Edit/Write directly.** Reach for the CLI only when a task needs the live app (search, templates, dataview, the vault API).

## Where things live

```
docs/obsidian/
  .obsidian/          vault config — app.json, plugins/, themes/, templates.json (don't hand-edit unless asked)
  copilot/            Copilot custom prompts
  data/               game data notes (stats, victories, starship-archetypes)
  research/           design research (match-3 modifiers, effects, puzzle design, starship modules)
  drawings/           Excalidraw drawings → use the `excalidraw` skill, NOT this one
```

Key plugins enabled: **dataview** (queries over notes), **templater** + core templates, **excalidraw**, **kanban**, **linter**, **calendar/daily-notes**, **copilot**, **realclaudian**. If a note has ```` ```dataview ```` blocks or `<% %>` template syntax, it's rendered by those plugins — the raw file is the source of truth; the CLI sees the rendered result.

## The `obsidian` CLI

The official CLI (https://obsidian.md/cli). It drives the live app, not the raw files — so it sees the indexed/rendered vault, not just text on disk.

Syntax: `obsidian <command>[:<subcommand>] key=value …` — quote values with spaces. Add `format=json` for machine-readable output; `vault="Name"` to target a specific vault.

When to use it (vs. plain Read/Edit): anything that needs the app's index or API — full-vault search, resolving links/tags, daily-note flow, templates, or running JS against `app.*`.

```bash
obsidian search query="starship modules" format=json   # search the indexed vault (json = parseable)
obsidian read                                            # print the currently-open file
obsidian create name="New Encounter" template=Travel     # new note from a template
obsidian daily                                           # open/print today's daily note
obsidian daily:append content="- [ ] playtest match-3"   # append to daily note
obsidian tasks daily                                     # list tasks from the daily note
obsidian tags counts                                     # all tags with frequencies
obsidian unresolved                                      # find broken/unresolved links
obsidian diff file=README from=1 to=3                    # compare file versions
```

Dev / plugin work (also needs the app running):

```bash
obsidian eval "app.vault.getFiles().length"   # run JS against the vault API
obsidian devtools                              # open DevTools
obsidian plugin:reload realclaudian            # reload a plugin you're developing
obsidian dev:screenshot file=shot.png          # screenshot the app UI
obsidian dev:errors                            # recent JS errors
obsidian dev:dom selector=".nav"               # query the DOM
obsidian dev:css selector=".workspace"         # inspect computed CSS
```

`obsidian eval` is the escape hatch — anything the app can do (read/move/tag notes, query metadata cache, drive plugins) is reachable through `app.*`.

## Gotchas

- For pure text edits, skip the CLI and edit the `.md` file directly — it's faster and needs nothing running.
- Editing `.obsidian/*.json` by hand can corrupt vault state and may need an app reload to take effect — only do it when asked.
- Drawings are `*.excalidraw.md` — handled by the `excalidraw` skill, not here.
