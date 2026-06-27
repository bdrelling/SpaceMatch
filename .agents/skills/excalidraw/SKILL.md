---
name: excalidraw
description: Create/edit Excalidraw drawings in the Obsidian vault (docs/obsidian/drawings/*.excalidraw.md) by writing JSON directly — no GUI. Default file is whiteboard; pass a name for a separate drawing. Triggers "add to the whiteboard", "draw X in excalidraw", "sketch this in the vault", "edit whiteboard.excalidraw". NOT the live TV/iPad whiteboard skill.
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
- `write(name, els, opts?)` → path. `opts.appState` overrides theme/`viewBackgroundColor` (default dark, `#0d1117`).
- `read(name)` → `{ elements, ... }`. To extend an existing drawing: `read`, push to `elements`, `write` back.

Coords: +x right, +y down. Group related shapes with a shared `groupIds: ["x"]` so they move together.

## Verify

```bash
node -e 'const{elements:e}=require("./.agents/skills/excalidraw/excalidraw.js").read("whiteboard");console.log(e.length,"elements OK")'
```

Then give the user a clickable link: `file:///Users/brian/Developer/bdrelling/games/SpaceMatch/docs/obsidian/drawings/whiteboard.excalidraw.md`
