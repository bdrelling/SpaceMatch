// build.js — reusable machinery for schema / ER-style Excalidraw diagrams (note -> drawing).
// You supply the per-drawing DATA (a composition tree + a few shared-leaf placements); this file
// owns everything generic: box sizing, color-by-kind, top-down tree layout, direction-aware arrow
// routing, the boxed key, and writing a valid .excalidraw.md. Pair with render.js (drawing -> image).
//
//   const { Diagram } = require("./build.js");
//   const d = new Diagram();
//   d.layoutTree(TREE);                       // TREE = nested {n, f, note, riders, kids, fromRow, spacer}
//   d.place("Phase", x, y, 150, ["A","B"], "enum");   // shared leaves placed manually
//   d.stack(x, 150, d.box.Phase.bottom + 10, [{n:"X", note:"extends Phase"}]);
//   d.treeEdges(TREE);                        // composition arrows, parent -> child
//   d.fk("DealDamage", 0, "Amount");          // a cross-reference arrow, field-row -> target box
//   d.title("Effect System", "mirrors notes/effect-system.md");
//   d.key([["root","Root — base type"], ["sub","Subtype — extends a root"], ["enum","Enum"]]);
//   d.write("effect-system");
//
// Color rule: note starting "extends" => sub (green); note "enum" => enum (amber); else root (blue).

const E = require("../excalidraw.js");

const KINDS = {
  root: { strokeColor: "#58a6ff", headColor: "#14304d", titleColor: "#cfe6ff" },
  sub:  { strokeColor: "#3fb950", headColor: "#103021", titleColor: "#b9f0c9" },
  enum: { strokeColor: "#d29922", headColor: "#3d2c08", titleColor: "#ffe2a8" },
};
const HBOX = (f, note) => 30 + (note ? 34 : 0) + ((f ? f.length : 0) * 22) + 8;
function boxW(name, f, note) {
  let w = name.length * 9 + 30;
  if (f) for (const s of f) w = Math.max(w, s.length * 7.5 + 28);
  if (note) w = Math.max(w, note.length * 7.2 + 26);
  return Math.max(132, Math.ceil(w));
}
function kindOf(note) { return !note ? "root" : note.indexOf("extends") === 0 ? "sub" : note === "enum" ? "enum" : "root"; }
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

class Diagram {
  constructor(opts = {}) {
    this.els = [];
    this.box = {};
    this.depthY = opts.depthY || [140, 290, 470, 720, 880, 1040];
    this.hgap = opts.hgap || 50;
    this.rvgap = opts.rvgap || 10;
    this.left0 = opts.left0 || 60;
  }
  place(name, x, y, w, fields, note) {
    const k = KINDS[kindOf(note)];
    const s = E.schema(Math.round(x), Math.round(y), w, name, fields || [], { ...k, ...(note ? { note } : {}) });
    this.els.push(...s.elements); this.box[name] = s; return s;
  }
  // place a list of riders [{n,f,note}] stacked vertically from startY; returns next y.
  stack(x, w, startY, riders) {
    let y = startY;
    for (const r of riders) { const b = this.place(r.n, x, y, w, r.f, r.note); y = b.bottom + this.rvgap; }
    return y;
  }
  _slotW(n) { let w = boxW(n.n, n.f, n.note); if (n.riders) for (const r of n.riders) w = Math.max(w, boxW(r.n, r.f, r.note)); return w; }
  _hlayout(n, depth, left) {
    n.y = this.depthY[depth];
    if (n.spacer) { n._span = n.spacerW; n._cx = left + n._span / 2; return; }
    n._w = (n.kids && n.kids.length) ? boxW(n.n, n.f, n.note) : this._slotW(n);
    if (n.kids && n.kids.length) {
      let x = left;
      for (const k of n.kids) { this._hlayout(k, depth + 1, x); x += k._span + this.hgap; }
      const span = x - this.hgap - left;
      n._span = Math.max(span, n._w); n._cx = left + span / 2;
    } else { n._span = n._w; n._cx = left + n._span / 2; }
  }
  _render(n) {
    if (n.spacer) return;
    const x = n._cx - n._w / 2;
    this.place(n.n, x, n.y, n._w, n.f, n.note);
    if (n.riders) this.stack(x, n._w, this.box[n.n].bottom + this.rvgap, n.riders);
    if (n.kids) for (const k of n.kids) this._render(k);
  }
  // lay out + render a composition tree (top-down; breadth spreads horizontally).
  layoutTree(tree) { this._hlayout(tree, 0, this.left0); this._render(tree); return this; }
  // composition arrows: every non-spacer kid gets a parent -> child arrow.
  treeEdges(tree) {
    const walk = n => { if (n.kids) for (const k of n.kids) if (!k.spacer) { this.linkDown(n.n, k.n); walk(k); } };
    walk(tree); return this;
  }
  linkDown(parent, child) {
    const p = this.box[parent], c = this.box[child];
    this.els.push(E.link(clamp(c.cx, p.left + 12, p.right - 12), p.bottom, c.cx, c.top));
  }
  // direction-aware reference arrow: src field-row -> dst box (right / left / vertical).
  fk(src, row, dst) {
    const s = this.box[src], d = this.box[dst];
    if (d.left >= s.right) this.els.push(E.link(s.right, s.rowY(row), d.left, d.cy));
    else if (d.right <= s.left) this.els.push(E.link(s.left, s.rowY(row), d.right, d.cy));
    else { const up = d.cy < s.cy; this.els.push(E.link(s.cx, up ? s.top : s.bottom, d.cx, up ? d.bottom : d.top)); }
  }
  title(t, sub) {
    this.els.push(E.text(60, 20, t, { fontSize: 28, fontFamily: 2, strokeColor: "#e6edf3" }));
    if (sub) this.els.push(E.text(62, 56, sub, { fontSize: 13, fontFamily: 1, strokeColor: "#8b949e" }));
    return this;
  }
  // boxed legend, top-left. rows = [[kindNameOrHex, label], ...]
  key(rows) {
    const KX = 60, KY = 84, KW = 252, KH = 24 + rows.length * 26 + 14;
    this.els.push(E.rect(KX, KY, KW, KH, { strokeColor: "#30363d", backgroundColor: "#161b22", roughness: 0, strokeWidth: 1 }));
    this.els.push(E.text(KX + 14, KY + 9, "Key", { fontSize: 14, fontFamily: 2, strokeColor: "#e6edf3" }));
    rows.forEach(([c, label], i) => {
      const color = KINDS[c] ? KINDS[c].strokeColor : c;
      const y = KY + 36 + i * 26;
      this.els.push(E.rect(KX + 14, y, 20, 14, { strokeColor: color, backgroundColor: color, fillStyle: "solid", roughness: 0, strokeWidth: 1 }));
      this.els.push(E.text(KX + 44, y - 2, label, { fontSize: 13, fontFamily: 2, strokeColor: "#c9d1d9" }));
    });
    return this;
  }
  write(name) { return E.write(name, this.els); }
}

module.exports = { Diagram, KINDS, HBOX, boxW, kindOf };
