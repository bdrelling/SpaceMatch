# Screen Composition

How screens are put together. Feature scenes are raw; a reusable frame supplies the chrome; composite
screens drop a raw feature scene into the frame.

## Feature scenes are raw

A feature scene is just the feature. Open `match.tscn` and you get only the match — no top bar, no
bottom bar, no background, no safe area. Same for the loadout. They fill whatever frame they're handed
and know nothing about how they're presented. (Verified: `match.tscn` run on its own is the bare match.)

## ScreenFrame — the reusable container

`source/ui/screen_frame/` is the standard frame: app `Background`, a `SafeAreaContainer`, a
`ScreenTopBar`, and a `Content` slot below the bar. Built once. API: `configure_bar(title, action)`,
`hide_bar()`, `set_content(node)`, and `back_pressed` / `action_pressed` signals.

It reuses the smaller pieces: `ScreenContainer` (background + safe area) and `ScreenTopBar` exist on
their own too — `ScreenFrame` is the assembled version with a content slot.

## Composite screens

A composite screen instances `ScreenFrame` and drops a raw feature scene into its `Content` slot, then
configures the bar and wires behavior:

- `EncounterScreen` = `ScreenFrame` + `match.tscn`, session bound in. The same match content, in the
  lightweight standard frame instead of the `Game` shell.
- `LoadoutScreen` = `ScreenFrame` + the loadout scene; Back → menu, Launch → encounter (carrying the
  session).
- `DebugScreen` = `ScreenFrame` (bar hidden) + the `DebugNavigator`, which brings its own bar.
- `MainMenu` stays on the bare `ScreenContainer` (background + safe area, no bar) — it's the title screen.

The point: the same feature scene can be hosted by more than one composite screen (the match lives in
both the `Game` shell and `EncounterScreen`), because the feature scene carries no chrome.

## Flow

Quick Match → `LoadoutScreen` → Launch → `EncounterScreen` (the match, with the chosen loadout). The
`Game` shell remains the boot target / richer encounter; both host the same raw `match.tscn`.

## Not a navigation stack

No router/push-pop machinery — the game has no dynamic screen sequences. Composition (raw feature scene
in a frame) covers every case. Don't re-propose a nav stack.
