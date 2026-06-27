// Zero-dependency server: serves the bundled front-end in ./public and a tiny
// scene-sync API. No network access required at runtime.
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 7000;
const PUB = path.join(__dirname, "public");
const DATA = path.join(__dirname, "data");
const SCENE = path.join(DATA, "scene.json");
const SNAP = path.join(DATA, "snapshot.png");
const EMPTY = '{"elements":[],"files":{}}';

fs.mkdirSync(DATA, { recursive: true });

const TYPES = {
  ".html": "text/html", ".js": "text/javascript", ".css": "text/css",
  ".json": "application/json", ".woff2": "font/woff2", ".woff": "font/woff",
  ".ttf": "font/ttf", ".png": "image/png", ".svg": "image/svg+xml", ".ico": "image/x-icon",
};

function send(res, code, type, body) {
  res.writeHead(code, { "Content-Type": type, "Cache-Control": "no-store" });
  res.end(body);
}

http.createServer((req, res) => {
  const { method } = req;
  const p = req.url.split("?")[0];

  if (method === "GET" && p === "/api/scene")
    return send(res, 200, "application/json", fs.existsSync(SCENE) ? fs.readFileSync(SCENE) : EMPTY);

  if (method === "GET" && p === "/api/snapshot.png") {
    if (!fs.existsSync(SNAP)) return send(res, 404, "text/plain", "no snapshot yet");
    return send(res, 200, "image/png", fs.readFileSync(SNAP));
  }

  if (method === "POST" && p === "/api/scene") {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      try {
        const x = JSON.parse(Buffer.concat(chunks).toString());
        fs.writeFileSync(SCENE, JSON.stringify({ elements: x.elements || [], files: x.files || {} }));
        if (x.png) fs.writeFileSync(SNAP, Buffer.from(x.png.replace(/^data:image\/png;base64,/, ""), "base64"));
        send(res, 200, "application/json", '{"ok":true}');
      } catch (e) {
        send(res, 400, "text/plain", String(e));
      }
    });
    return;
  }

  // Static files from ./public.
  if (method === "GET") {
    const file = path.join(PUB, path.normalize(p === "/" ? "/index.html" : p));
    if (file.startsWith(PUB) && fs.existsSync(file) && fs.statSync(file).isFile())
      return send(res, 200, TYPES[path.extname(file)] || "application/octet-stream", fs.readFileSync(file));
  }

  send(res, 404, "text/plain", "not found");
}).listen(PORT, () => console.log("whiteboard on :" + PORT));
