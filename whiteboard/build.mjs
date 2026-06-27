// Bundles the front-end into ./public so the running image needs no network.
import * as esbuild from "esbuild";
import { cpSync, mkdirSync, existsSync } from "fs";

mkdirSync("public", { recursive: true });

// Excalidraw's prebuilt runtime assets (hand-drawn fonts, etc.). Copied first so
// the esbuild output below isn't clobbered. Served from "/" via EXCALIDRAW_ASSET_PATH.
const assets = "node_modules/@excalidraw/excalidraw/dist/prod";
if (existsSync(assets)) cpSync(assets, "public", { recursive: true });

await esbuild.build({
  entryPoints: ["src/app.js"],
  bundle: true,
  format: "esm",
  outfile: "public/app.js",
  minify: true,
  conditions: ["production"],
  loader: { ".woff2": "file", ".woff": "file", ".ttf": "file", ".svg": "dataurl", ".png": "dataurl" },
  assetNames: "assets/[name]-[hash]",
  define: { "process.env.NODE_ENV": '"production"' },
  logLevel: "info",
});

cpSync("src/index.html", "public/index.html");
console.log("build complete -> public/");
