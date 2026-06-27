import React from "react";
import { createRoot } from "react-dom/client";
import { Excalidraw, exportToBlob } from "@excalidraw/excalidraw";
import "@excalidraw/excalidraw/index.css";

let api = null;            // Excalidraw imperative API
let lastSynced = "[]";     // serialized elements we last pushed OR loaded
let applyingRemote = false;
let pushTimer = null;

const blobToDataURL = (blob) =>
  new Promise((r) => { const fr = new FileReader(); fr.onload = () => r(fr.result); fr.readAsDataURL(blob); });

// Local edits -> server (debounced). Also exports a PNG so the agent can *see* the board.
async function pushScene() {
  if (!api) return;
  const elements = api.getSceneElements();
  const key = JSON.stringify(elements);
  if (key === lastSynced) return;
  lastSynced = key;
  const files = api.getFiles();
  let png = null;
  try {
    const blob = await exportToBlob({
      elements, files,
      appState: { exportBackground: true, viewBackgroundColor: "#ffffff" },
      mimeType: "image/png",
    });
    png = await blobToDataURL(blob);
  } catch (_) {}
  fetch("/api/scene", { method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ elements, files, png }) }).catch(() => {});
}

// Server (agent's edits) -> canvas.
async function pullScene() {
  if (!api) return;
  try {
    const data = await (await fetch("/api/scene", { cache: "no-store" })).json();
    const elements = data.elements || [];
    const key = JSON.stringify(elements);
    if (key === lastSynced) return;
    lastSynced = key;
    applyingRemote = true;
    if (data.files && Object.keys(data.files).length) api.addFiles(Object.values(data.files));
    api.updateScene({ elements });
    applyingRemote = false;
  } catch (_) {}
}

function onChange() {
  if (applyingRemote) return;
  clearTimeout(pushTimer);
  pushTimer = setTimeout(pushScene, 500);
}

const App = () => React.createElement(Excalidraw, {
  excalidrawAPI: (a) => { api = a; pullScene(); },
  onChange,
});

createRoot(document.getElementById("root")).render(React.createElement(App));
setInterval(pullScene, 1500);
