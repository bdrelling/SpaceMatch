# AGENTS.md

`mockups/<name>/` — self-contained HTML click-through mockups (inline CSS/JS, no build, no deps). Each dir has a `README.md` that IS the brief: the design decisions, what was tried and rejected, what's mocked vs. not, and the render path.

## Getting a mockup "in context"

**Read that dir's `README.md`. That's the whole job — you're now ready.** The README is written to carry the full design in prose; reading it is having the mockup in context.

- **Do NOT render it to PNG to "see" it.** Rendering tells you nothing the README doesn't, costs a browser launch, and in a cloud/CI container there's no browser — so it dead-ends or tempts an improvised, broken command. A picture is not context here; the README is.
- **Do NOT read `index.html` to reconstruct the design.** Read it only when you're *editing* the mockup.
- **Absorb the design; don't acknowledge the scaffolding.** The README's decisions are settled facts — apply them silently. Don't report which sections you read, and don't parrot its framing back ("noted the *settled / don't-relitigate / tried-and-rejected* lists"). That acknowledgment is pure noise; the labels exist to shape your edits, not to be echoed.
- When asked to "get the mockup in context and be ready," the answer is: read the README, then say you're ready in a line or two. No rendering, no `index.html` spelunking, no wall of context or section-by-section recap echoed back.

## Rendering to PNG (only when a human needs an actual image)

Render only when the user explicitly wants to *look* at a screen — never as a step toward understanding.

```sh
mockups/render.sh <name> [screen-id] [scroll-px]   # e.g. mockups/render.sh debug-menu ed_status
```

`render.sh` is the ONLY supported way to render — it resolves whatever headless browser exists (puppeteer cache → PATH → macOS app). **Don't hand-roll a `chromium`/`google-chrome` call**; that's the broken-command trap. Screen ids come from the `SCREENS` registry in `index.html`; omit the screen for the home screen. Exit code 3 means no browser is available (normal in cloud containers) — that's expected, not a failure to fix: fall back to the README, which describes the design fully.

## Reviewing / editing

- Reviewing: after the README, render the key screens only if the user wants images. Give a **tight** read — a few lines on whether it holds together. Don't echo the design rationale back; the README already carries it.
- Editing: honor the README's settled decisions and house style. Don't relitigate them.
