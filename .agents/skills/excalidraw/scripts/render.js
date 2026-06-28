#!/usr/bin/env node
// Rasterize an Obsidian-Excalidraw drawing to PNG by replaying its JSON elements as SVG,
// then converting with rsvg-convert. Reads the LIVE .excalidraw.md (never a stale auto-export).
// Faithful to geometry / text / colors / freehand stroke paths; omits Excalidraw's rough.js
// "sketchy" styling and uses system fonts (text widths may differ slightly).
//
//   node scripts/render.js <drawing-name|path-to-.md> [zoom]
//   -> writes /tmp/<name>.png and prints its absolute path
//
// Handles drawings stored flat (drawings/<name>.excalidraw.md) or in a folder
// (drawings/<name>/<name>.excalidraw.md), and both ```json and ```compressed-json blocks.
// Covers: rectangle, ellipse, diamond, line, arrow, freedraw, text. Skips embedded images.

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const { DRAWINGS_DIR } = require("../excalidraw.js");

const arg = process.argv[2];
if (!arg) { console.error("usage: render.js <drawing-name|path-to-.md> [zoom]"); process.exit(1); }
const zoom = process.argv[3] || "1.3";

function resolveFile(a) {
  if (a.endsWith(".md") && fs.existsSync(a)) return path.resolve(a);
  const cands = [path.join(DRAWINGS_DIR, `${a}.excalidraw.md`), path.join(DRAWINGS_DIR, a, `${a}.excalidraw.md`)];
  for (const c of cands) if (fs.existsSync(c)) return c;
  throw new Error("drawing not found; tried:\n  " + cands.join("\n  "));
}
function loadScene(file) {
  const md = fs.readFileSync(file, "utf8");
  let m = md.match(/```json\n([\s\S]*?)\n```/);
  if (m) return JSON.parse(m[1]);
  m = md.match(/```compressed-json\n([\s\S]*?)```/);
  if (m) { const LZ = require("lz-string"); return JSON.parse(LZ.decompressFromBase64(m[1].replace(/[\n\r]/g, "").trim())); }
  throw new Error("no drawing block found in " + file);
}

const file = resolveFile(arg);
const name = path.basename(file).replace(/\.excalidraw\.md$/, "");
const scene = loadScene(file);
const elements = scene.elements.filter(e => !e.isDeleted);
const bg = (scene.appState && scene.appState.viewBackgroundColor) || "#0d1117";

const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const fam = f => f === 3 ? "'Menlo','DejaVu Sans Mono',monospace" : f === 1 ? "'Comic Sans MS','Segoe Print',sans-serif" : "'Helvetica Neue',Arial,sans-serif";
const fill = e => (!e.backgroundColor || e.backgroundColor === "transparent") ? "none" : e.backgroundColor;
const pathOf = e => e.points.map((p, i) => (i ? "L" : "M") + (e.x + p[0]) + " " + (e.y + p[1])).join(" ");

let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
for (const e of elements) {
  const xs = [e.x, e.x + (e.width || 0)], ys = [e.y, e.y + (e.height || 0)];
  if (e.points) for (const p of e.points) { xs.push(e.x + p[0]); ys.push(e.y + p[1]); }
  minX = Math.min(minX, ...xs); maxX = Math.max(maxX, ...xs); minY = Math.min(minY, ...ys); maxY = Math.max(maxY, ...ys);
}
const PAD = 30; minX -= PAD; minY -= PAD; maxX += PAD; maxY += PAD;
const W = Math.ceil(maxX - minX), H = Math.ceil(maxY - minY);

const out = [`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="${minX} ${minY} ${W} ${H}">`,
  `<rect x="${minX}" y="${minY}" width="${W}" height="${H}" fill="${bg}"/>`];

function arrowhead(x1, y1, x2, y2, c) {
  const a = Math.atan2(y2 - y1, x2 - x1), L = 9, s = 0.45;
  return `<path d="M${x2 - L * Math.cos(a - s)} ${y2 - L * Math.sin(a - s)} L${x2} ${y2} L${x2 - L * Math.cos(a + s)} ${y2 - L * Math.sin(a + s)}" fill="none" stroke="${c}" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/>`;
}

let skipped = {};
for (const e of elements) {
  if (e.type === "rectangle") out.push(`<rect x="${e.x}" y="${e.y}" width="${e.width}" height="${e.height}" rx="${e.roundness ? 6 : 0}" fill="${fill(e)}" stroke="${e.strokeColor}" stroke-width="${e.strokeWidth || 1}"/>`);
  else if (e.type === "ellipse") out.push(`<ellipse cx="${e.x + e.width / 2}" cy="${e.y + e.height / 2}" rx="${e.width / 2}" ry="${e.height / 2}" fill="${fill(e)}" stroke="${e.strokeColor}" stroke-width="${e.strokeWidth || 1}"/>`);
  else if (e.type === "diamond") { const cx = e.x + e.width / 2, cy = e.y + e.height / 2; out.push(`<polygon points="${cx},${e.y} ${e.x + e.width},${cy} ${cx},${e.y + e.height} ${e.x},${cy}" fill="${fill(e)}" stroke="${e.strokeColor}" stroke-width="${e.strokeWidth || 1}"/>`); }
  else if (e.type === "arrow" || e.type === "line") { out.push(`<path d="${pathOf(e)}" fill="none" stroke="${e.strokeColor}" stroke-width="${e.strokeWidth || 1}" stroke-linecap="round" stroke-linejoin="round"/>`); const p = e.points; if (e.endArrowhead === "arrow" && p.length >= 2) out.push(arrowhead(e.x + p[p.length - 2][0], e.y + p[p.length - 2][1], e.x + p[p.length - 1][0], e.y + p[p.length - 1][1], e.strokeColor)); }
  else if (e.type === "freedraw") out.push(`<path d="${pathOf(e)}" fill="none" stroke="${e.strokeColor}" stroke-width="${e.strokeWidth || 2}" stroke-linecap="round" stroke-linejoin="round"/>`);
  else if (e.type !== "text") skipped[e.type] = (skipped[e.type] || 0) + 1;
}
for (const e of elements) {
  if (e.type !== "text") continue;
  const anchor = e.textAlign === "center" ? "middle" : e.textAlign === "right" ? "end" : "start";
  const tx = e.textAlign === "center" ? e.x + (e.width || 0) / 2 : e.textAlign === "right" ? e.x + (e.width || 0) : e.x;
  String(e.text).split("\n").forEach((ln, i) => out.push(`<text x="${tx}" y="${e.y + e.fontSize * 0.82 + i * e.fontSize * 1.25}" font-family="${fam(e.fontFamily)}" font-size="${e.fontSize}" fill="${e.strokeColor}" text-anchor="${anchor}">${esc(ln)}</text>`));
}
out.push("</svg>");

const svgPath = path.join("/tmp", `${name}.svg`), pngPath = path.join("/tmp", `${name}.png`);
fs.writeFileSync(svgPath, out.join("\n"));
execFileSync("rsvg-convert", ["-z", String(zoom), svgPath, "-o", pngPath]);
if (Object.keys(skipped).length) console.error("skipped unsupported types:", JSON.stringify(skipped));
console.log(pngPath);
