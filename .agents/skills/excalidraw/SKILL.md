---
name: excalidraw
description: Create/edit Excalidraw drawings in the Obsidian vault by writing JSON directly — no GUI. Default file is whiteboard; pass a name for a separate drawing. Triggers "add to the whiteboard", "draw X in excalidraw", "sketch this in the vault", "edit whiteboard.excalidraw". NOT the live TV/iPad whiteboard skill.
argument-hint: optional drawing name (default whiteboard)
---

# excalidraw

Write Excalidraw drawings as plain text. The bundled helper stamps every required field, so nothing gets silently dropped.

## What's here

- `excalidraw.js` — low-level element factories + `write`/`read` (stamps every required field).
- `scripts/build.js` — the **layout engine** for schema / ER / composition diagrams. Use this, not hand-placed boxes — see below.
- `scripts/render.js` — drawing → PNG preview.
- `examples/effect-system.js` — full worked reference (and the engine's smoke test).

## Editing or rebuilding an existing drawing — DO THIS FIRST

Every engine-built drawing has a **generator script that is its source of truth** — the `.excalidraw.md` is the *output*, never edited by hand. Generators live at `examples/<drawing-name>.js` (the `effect-system` drawing ⇒ `examples/effect-system.js`).

To change or "rebuild" a drawing: **find its generator, edit the data, re-run it, render to verify.** Never hand-edit or reverse-engineer the `.excalidraw.md`, and never author a fresh generator from scratch — the existing one is there. It lives under `.claude/`, which is gitignored, so `rg`/Glob skip it; look directly with `ls .claude/skills/excalidraw/examples/`.

```bash
node .claude/skills/excalidraw/examples/<name>.js         # regenerate the .excalidraw.md
node .claude/skills/excalidraw/scripts/render.js <name>   # preview the PNG
```

## Files (naming rule)

- Default: `docs/obsidian/drawings/whiteboard.excalidraw.md`
- Named (user names one, or asks for a separate drawing): `docs/obsidian/drawings/<name>.excalidraw.md`

One drawing = one `.excalidraw.md`. Never put a second drawing into an existing file.

## The one gotcha

These are Obsidian-plugin markdown files. The drawing lives in a fenced block that is usually ```` ```compressed-json ````. **You can't hand-edit compressed JSON.** Always write the `write()` output, which emits an uncompressed ```` ```json ```` block — the plugin loads it fine and re-compresses on next save. Every element MUST carry the full field set (`index`, `groupIds`, `seed`, `frameId`, …) or Excalidraw drops it; the helper does this for you.

## Do this

```bash
cd /Users/brian/Developer/bdrelling/games/SpaceMatch && node -e '
const E = require("./.agents/skills/excalidraw/excalidraw.js");
const els = [];

els.push(E.text(300, 70, "✦  TITLE  ✦", { fontSize: 34, strokeColor: "#ffd43b", textAlign: "center", width: 420 }));
els.push(E.rect(330, 215, 80, 150, { strokeColor: "#4dabf7", backgroundColor: "#1864ab" }));
els.push(E.ellipse(348, 245, 44, 44, { strokeColor: "#ffe066", backgroundColor: "#fff3bf" }));

// closed/filled shape: relative points, first==last. Group via shared groupIds.
const g = "grp1";
els.push(E.poly(330, 150, [[0,70],[40,0],[80,70],[0,70]], { strokeColor:"#ff8787", backgroundColor:"#c92a2a", groupIds:[g] }));
els.push(E.arrow(560, 245, [[0,0],[120,0]], { strokeColor:"#e9ecef" }));

console.log("wrote", E.write("whiteboard", els));   // or E.write("roadmap", els)
'
```

## Helper API (`excalidraw.js`)

- `rect(x,y,w,h,opts)` · `ellipse(...)` · `diamond(...)` — opts: `strokeColor`, `backgroundColor`, `groupIds`, `strokeWidth`, `roughness`, `angle`.
- `poly(x,y,points,opts)` — closed polygon (filled if first==last). `arrow(x,y,points,opts)`.
- `text(x,y,str,opts)` — opts: `fontSize`, `strokeColor`, `textAlign`, `width`, `fontFamily` (1=hand-drawn, 2=normal, 3=code). `\n` for multi-line.
- `schema(x,y,w,title,fields,opts)` — a Swagger-style entity box (see ER recipe below). Returns `{ elements, left, right, top, bottom, cx, cy, rowY(i) }`.
- `link(ax,ay,bx,by,opts)` — thin foreign-key arrow between two absolute points.
- `write(name, els, opts?)` → path. `opts.appState` overrides theme/`viewBackgroundColor` (default dark, `#0d1117`).
- `read(name)` → `{ elements, ... }`. To extend an existing drawing: `read`, push to `elements`, `write` back.

Coords: +x right, +y down. Group related shapes with a shared `groupIds: ["x"]` so they move together.

## Schema / ER / composition diagrams → use the engine (`scripts/build.js`)

Anything that's typed boxes + relationships — ER, data-model, class/composition, system structure — goes through the `Diagram` engine in `scripts/build.js`. **Don't hand-place boxes.** You describe the *data* (boxes, fields, edges) as a tree; the engine owns all the layout + Excalidraw-compat work: box sizing, top-down tree / column placement, direction-aware arrow routing, color-by-kind, the legend, and writing a valid `.excalidraw.md`. The engine is the reusable part, so layout is never re-solved by hand; the per-drawing data lives in that drawing's generator script — **saved, not throwaway**, since it's how the drawing gets edited and rebuilt later (see "Editing or rebuilding an existing drawing" above). Source-agnostic: the data can come from a markdown note or straight from a conversation — the engine never reads either, it takes the structure you build.

**Full worked reference + smoke test:** `examples/effect-system.js` (40+ boxes, every feature). Copy its shape. Re-run any example with `node .agents/skills/excalidraw/examples/<name>.js`.

House style (baked into the engine):

- One box per type: title header, then `field : Type` rows (monospace). Spell every real field out — read the `*_state.gd` / `*_blueprint.gd` first; never summarize as "all int".
- **Color by kind**, decided from each node's `note`: no note = `root` (blue); `note:"extends X"` = `sub` (green); `note:"enum"` = `enum` (amber). `note:"base"` stays a root but reads as a base type you stack subtypes under.
- `extends X` / annotations live in `note` — a centered line under the title in the hand-drawn font (Excalidraw has no real italic), with a gap before the fields.
- A reference field connects to the type it holds via `fk(srcBox, fieldRow, dstBox)` — direction-aware, no "1:N" labels; the arrow + field type carry it.
- Composition flows top-down; breadth spreads horizontally.

Engine API — `const { Diagram, HBOX } = require("./.agents/skills/excalidraw/scripts/build.js")`:

- `new Diagram(opts?)` — `opts.depthY / hgap / rvgap / left0` tune spacing.
- `layoutTree(tree)` — lay out + render a composition tree. Node = `{ n, f?, note?, kids?, riders?, spacer?, spacerW? }`: `f` = field rows, `riders` = subtypes stacked under the node, `spacer`+`spacerW` = an empty lane reserving width.
- `treeEdges(tree)` — parent→child composition arrows for the whole tree.
- `place(name, x, y, w, fields, note)` — manually place a box the tree can't (shared leaves). Stored in `d.box[name]` with anchors `.left/.right/.top/.bottom/.cx/.cy` and `.rowY(i)`.
- `stack(x, w, startY, riders)` — stack boxes downward; returns next y.
- `fk(srcName, fieldRow, dstName)` — reference arrow from a field row to a box (auto right/left/vertical).
- `title(t, sub?)` · `key(rows)` — title/subtitle + boxed legend (`rows = [["root","Root — base type"], …]`).
- `write(name)` — write `docs/obsidian/drawings/<name>.excalidraw.md`. `layoutTree`/`treeEdges`/`title`/`key` return the Diagram, so they chain.
- `HBOX(fields, note)` — box-height helper, to vertically center a manually-placed box against others.

```bash
cd /Users/brian/Developer/bdrelling/games/SpaceMatch && node -e '
const { Diagram } = require("./.agents/skills/excalidraw/scripts/build.js");
const TREE = { n:"GameState", f:["starship : StarshipState","wallet : WalletState"], kids:[
  { n:"StarshipState", f:["name : String","health : int"], kids:[
    { n:"DamageKind", f:["KINETIC","THERMAL"], note:"enum" } ] },
  { n:"WalletState", f:["credits : int"], note:"extends Resource" },
]};
const d = new Diagram();
d.layoutTree(TREE).treeEdges(TREE).title("Game State")
 .key([["root","Root"],["sub","extends a root"],["enum","Enum"]]);
console.log("wrote", d.write("game-state"));
'
```

For a tiny one-off (2–3 boxes, no hierarchy) you can hand-place raw `E.schema()` + `E.link()` (monochrome — gray stroke, no kind colors) per the helper API above. Past that, use the engine.

## Verify

```bash
node -e 'const{elements:e}=require("./.agents/skills/excalidraw/excalidraw.js").read("whiteboard");console.log(e.length,"elements OK")'
```

Then give the user a clickable link: `file:///Users/brian/Developer/bdrelling/games/SpaceMatch/docs/obsidian/drawings/whiteboard.excalidraw.md`

## Show it as an image

When the user asks to **see / show / preview an image** of a drawing, render it yourself — do NOT rely on Obsidian's auto-exported `.png`/`.svg` (those only refresh when Obsidian opens the file, so they go stale the moment the JSON changes or when you generate a drawing the user hasn't opened).

```bash
node .agents/skills/excalidraw/scripts/render.js <name>   # prints /tmp/<name>.png
```

Then `Read` that PNG to display it. The script reads the live `.excalidraw.md` (flat or in a `<name>/` folder; `json` or `compressed-json`), replays every element as SVG, and rasterizes with `rsvg-convert`. It's faithful to geometry / text / colors / freehand stroke paths — it omits Excalidraw's rough.js "sketchy" styling and uses system fonts (text widths may differ slightly). Covers rectangle, ellipse, diamond, line, arrow, freedraw, text; skips embedded images. Needs `rsvg-convert` (`brew install librsvg`).
