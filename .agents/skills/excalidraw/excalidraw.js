// Build & write Obsidian-Excalidraw-plugin drawings with every required field stamped.
// Zero deps for writing. Reading a *compressed* file lazily needs `lz-string`.
//
//   const E = require('/abs/path/.agents/skills/excalidraw/excalidraw.js');
//   const els = [];
//   els.push(E.rect(330, 215, 80, 150, { strokeColor: '#4dabf7', backgroundColor: '#1864ab' }));
//   els.push(E.text(300, 70, 'Hello', { fontSize: 34, strokeColor: '#ffd43b' }));
//   E.write('whiteboard', els);          // -> docs/obsidian/drawings/whiteboard.excalidraw.md  (default)
//   E.write('roadmap', els);             // -> docs/obsidian/drawings/roadmap.excalidraw.md      (named)
//   const { elements } = E.read('whiteboard');   // load existing (json OR compressed-json)

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '../../..');
const DRAWINGS_DIR = path.join(REPO_ROOT, 'docs/obsidian/drawings');
const SOURCE = 'https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/tag/2.19.2';

const rnd = () => Math.floor(Math.random() * 2 ** 31);
const id = () => Math.random().toString(36).slice(2, 12);

// ---- element factories (no index/seed needed; write() stamps them) ----
function base(type, x, y, w, h, o = {}) {
  return {
    id: o.id || id(), type, x, y, width: w, height: h, angle: o.angle || 0,
    strokeColor: o.strokeColor || '#e9ecef',
    backgroundColor: o.backgroundColor || 'transparent',
    fillStyle: o.fillStyle || 'solid', strokeWidth: o.strokeWidth || 2,
    strokeStyle: o.strokeStyle || 'solid', roughness: o.roughness ?? 1,
    opacity: o.opacity ?? 100, groupIds: o.groupIds || [], frameId: null,
    roundness: o.roundness || null, boundElements: o.boundElements || null,
    link: o.link || null, locked: false, isDeleted: false,
  };
}
function rect(x, y, w, h, o = {}) { return { ...base('rectangle', x, y, w, h, o), roundness: o.roundness || { type: 3 } }; }
function ellipse(x, y, w, h, o = {}) { return base('ellipse', x, y, w, h, o); }
function diamond(x, y, w, h, o = {}) { return base('diamond', x, y, w, h, o); }

// points are relative to (x,y); first==last to make a closed/filled shape
function _line(type, x, y, pts, o = {}) {
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  return {
    ...base(type, x, y, Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys), o),
    points: pts, lastCommittedPoint: null, startBinding: null, endBinding: null,
    startArrowhead: o.startArrowhead || null, endArrowhead: o.endArrowhead || null,
  };
}
function poly(x, y, pts, o = {}) { return _line('line', x, y, pts, o); }
function arrow(x, y, pts, o = {}) { return _line('arrow', x, y, pts, { endArrowhead: 'arrow', ...o }); }

function text(x, y, str, o = {}) {
  const fontSize = o.fontSize || 20;
  const lines = String(str).split('\n');
  const w = o.width || Math.max(1, ...lines.map(l => l.length)) * fontSize * 0.55;
  return {
    ...base('text', x, y, w, lines.length * fontSize * 1.25, o),
    text: str, originalText: str, fontSize, fontFamily: o.fontFamily || 1,
    textAlign: o.textAlign || 'left', verticalAlign: o.verticalAlign || 'top',
    containerId: o.containerId || null, lineHeight: 1.25, autoResize: true, baseline: fontSize,
  };
}

// ---- schema/ER box (Swagger-style: title header + `field : Type` rows) ----
// Returns { elements, geometry }. Push elements, then wire refs with link() using
// the returned anchors: `.right`/`.left`/`.top`/`.bottom`/`.cx`/`.cy` and `.rowY(i)`
// (vertical center of field row i — connect a reference field straight to its target).
// opts.note → a centered annotation line under the title (e.g. "extends GridState"),
// set apart by the hand-drawn font (Excalidraw text has no real italic) + a gap before fields.
function schema(x, y, w, title, fields, o = {}) {
  const HEADH = 30, ROWH = 22, PAD = 8, NOTEH = o.note ? 34 : 0;
  const h = HEADH + NOTEH + fields.length * ROWH + PAD;
  const stroke = o.strokeColor || '#c9d1d9';
  const els = [
    rect(x, y, w, h, { strokeColor: stroke, backgroundColor: o.backgroundColor || '#161b22', roughness: 0, strokeWidth: 1 }),
    rect(x, y, w, HEADH, { strokeColor: stroke, backgroundColor: o.headColor || '#30363d', roughness: 0, strokeWidth: 1 }),
    text(x, y + 7, title, { fontSize: 16, fontFamily: 2, textAlign: 'center', width: w, strokeColor: o.titleColor || '#ffffff' }),
  ];
  if (o.note) els.push(text(x, y + HEADH + 7, o.note, { fontSize: 13, fontFamily: 1, textAlign: 'center', width: w, strokeColor: '#8b949e' }));
  const fieldTop = y + HEADH + NOTEH;
  fields.forEach((f, i) => els.push(text(x + 12, fieldTop + i * ROWH + 4, f, { fontSize: 13, fontFamily: 3, textAlign: 'left', width: w - 20, strokeColor: o.fieldColor || '#c9d1d9' })));
  return {
    elements: els, x, y, w, h,
    left: x, right: x + w, top: y, bottom: y + h, cx: x + w / 2, cy: y + h / 2,
    rowY: i => fieldTop + i * ROWH + ROWH / 2,
  };
}
// foreign-key arrow between two absolute points (thin, clean, gray by default)
function link(ax, ay, bx, by, o = {}) {
  return arrow(ax, ay, [[0, 0], [bx - ax, by - ay]], { strokeColor: o.strokeColor || '#8b949e', roughness: 0, strokeWidth: 1, ...o });
}

// ---- io ----
const fileFor = name => path.join(DRAWINGS_DIR, `${name || 'whiteboard'}.excalidraw.md`);

// strictly-increasing fractional indices (fixed-width => lexical order == numeric)
const stampIndex = (e, i) => ({ ...e, index: 'a' + String(i).padStart(6, '0'), seed: rnd(), versionNonce: rnd(), updated: Date.now(), version: 1 });

function write(name, elements, opts = {}) {
  const scene = {
    type: 'excalidraw', version: 2, source: SOURCE,
    elements: elements.map(stampIndex),
    appState: { theme: 'dark', gridSize: null, viewBackgroundColor: '#0d1117', ...(opts.appState || {}) },
    files: opts.files || {},
  };
  JSON.parse(JSON.stringify(scene)); // validate serialisable
  const md = `---

excalidraw-plugin: parsed
tags: [excalidraw]

---
==⚠  Switch to EXCALIDRAW VIEW in the MORE OPTIONS menu of this document. ⚠== You can decompress Drawing data with the command palette: 'Decompress current Excalidraw file'. For more info check in plugin settings under 'Saving'


## Drawing
\`\`\`json
${JSON.stringify(scene)}
\`\`\`
%%`;
  fs.mkdirSync(DRAWINGS_DIR, { recursive: true });
  const out = fileFor(name);
  fs.writeFileSync(out, md);
  return out;
}

function read(name) {
  const md = fs.readFileSync(fileFor(name), 'utf8');
  const j = md.match(/```json\n([\s\S]*?)\n```/);
  if (j) return JSON.parse(j[1]);
  const c = md.match(/```compressed-json\n([\s\S]*?)```/);
  if (c) {
    let LZ;
    try { LZ = require('lz-string'); }
    catch { throw new Error('compressed file — run: (cd /tmp && npm i lz-string) then retry'); }
    return JSON.parse(LZ.decompressFromBase64(c[1].replace(/[\n\r]/g, '').trim()));
  }
  throw new Error('no drawing block found');
}

module.exports = { rect, ellipse, diamond, poly, arrow, text, schema, link, write, read, fileFor, DRAWINGS_DIR, REPO_ROOT };
