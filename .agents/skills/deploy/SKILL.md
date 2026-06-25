---
name: deploy
description: Export or deploy the game to any platform. Triggers whenever the user says "export" or "deploy" (e.g. "deploy to iphone", "export ios", "redeploy").
---

# deploy

Export and deploy go through `make` (which wraps `armory`). Never hand-roll `godot --export`, `xcodebuild`, or `devicectl`.

- Find the target: `make help`. Common: `make export-ios` then `make deploy-iphone`; also `deploy-ipad`, `deploy-ios-sim`, `export-macos`/`deploy-macos`, `export-android`, etc.
- Run each target **once**. Don't retry the same command, and don't switch to a different device/target unless the user asks.

## When a step fails — stop, don't dig

The failure message is almost always the diagnosis. Read it, report it in a line or two, stop. Do **not** edit code/config to force it through, and do **not** investigate beyond the error text.

**Device unavailable is terminal — hard stop.** If a deploy says the device is **unavailable / not found / not connected**, the device simply isn't reachable from here and nothing you run will change that. Report exactly that — name the device it wanted and that it's not connected — and stop. Do **NOT**:

- probe with `xctrace` / `devicectl` / `xcrun` to "confirm" it,
- read the armory scripts to see how detection works,
- retry the deploy, or
- fall back to another device (iPad/sim) on your own.

The user reconnects the device (or picks another target) and re-runs. A failed *device* deploy doesn't invalidate a successful *export* — no re-export needed on retry.

Only dig further when the error is genuinely opaque (no actionable message) — and even then: one quick look, then report.
