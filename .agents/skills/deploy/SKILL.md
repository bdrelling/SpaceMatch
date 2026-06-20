---
name: deploy
description: Export or deploy the game to any platform. Triggers whenever the user says "export" or "deploy" (e.g. "deploy to iphone", "export ios", "redeploy").
---

# deploy

Export and deploy go through `make` (which wraps `armory`). Never hand-roll `godot --export`, `xcodebuild`, or `devicectl`.

- Find the target: `make help`. Common: `make export-ios` then `make deploy-iphone`; also `deploy-ipad`, `deploy-ios-sim`, `export-macos`/`deploy-macos`, `export-android`, etc.
- If a step fails, **stop — don't modify code or config to force it through.** Assess whether it's a configuration issue, report what you find, and ask.
