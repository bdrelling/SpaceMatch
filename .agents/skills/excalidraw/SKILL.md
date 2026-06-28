---
name: excalidraw
description: Create/edit Excalidraw drawings in the Obsidian vault by writing JSON directly — no GUI. Default file is whiteboard; pass a name for a separate drawing. Triggers "add to the whiteboard", "draw X in excalidraw", "sketch this in the vault", "edit whiteboard.excalidraw". NOT the live TV/iPad whiteboard skill.
argument-hint: optional drawing name (default whiteboard)
---

# excalidraw

Write Excalidraw drawings as plain text. The bundled helper stamps every required field, so nothing gets silently dropped.

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

## Entity / relationship diagrams (the house style)

When the user asks for an **entity diagram, relationship diagram, ER diagram, or data-model** drawing, render it like a Swagger schema / database ER chart, NOT freeform boxes:

- One `schema()` box per entity: title in the header, then `field : Type` rows (monospace via fontFamily 3). List the real fields from the code — read the `*_state.gd` / `*_blueprint.gd` first; don't summarize a field set as "all int", spell every field out.
- **Monochrome.** No fills-as-color, no decorative glyphs (`✦`) in the title — just the plain title text. The default schema palette (gray stroke, dark body, lighter header) is the look.
- A reference field points at the entity it holds via `link()` from `box.right/left, box.rowY(i)` straight into the target's `left/right, cy`. No "1:N" labels — the arrow + field type carry it.
- A base class / mixin goes in `opts.note` — a centered annotation right under the title (set apart by the hand-drawn font, since Excalidraw text has no real italic), with a gap before the fields. Use it for `extends X`.
- Lay entities out in columns by depth (root → owned → leaf); cross-links are fine.

```bash
cd /Users/brian/Developer/bdrelling/games/SpaceMatch && node -e '
const E = require("./.agents/skills/excalidraw/excalidraw.js");
const els = [];
els.push(E.text(60, 20, "Entity Relationships", { fontSize:26, fontFamily:2, strokeColor:"#e6edf3" }));
const a = E.schema(60, 120, 230, "GameState", ["starship : StarshipState", "wallet : WalletState"]);
const b = E.schema(360, 80,  260, "StarshipState", ["name : String", "health : int", "stats : StatBlock"]);
const c = E.schema(360, 280, 250, "ModuleGridState", ["columns : int", "rows : int"], { note:"extends GridState" });
for (const s of [a,b,c]) els.push(...s.elements);
els.push(E.link(a.right, a.rowY(0), b.left, b.cy));   // GameState.starship -> StarshipState
els.push(E.link(b.right, b.rowY(2), c.left, c.cy));   // ref field -> its type, by row
console.log("wrote", E.write("entity-relationships", els));
'
```

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
