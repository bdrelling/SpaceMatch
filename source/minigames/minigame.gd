class_name Minigame
extends Control
## Base for every game stage: a self-contained board plus a small view-model the shell reads to fill
## its chrome. The minigame owns its board, canvas, and input; it never draws the title bar, tab bar, or
## inventory strip. It only exposes [member status_text], its [method actions], and its
## [method inventory_chips] / [method inventory_detail], and the [Game] shell renders them — so the
## same chrome frames every stage and a stage stays just its board and rules.

## The one-line status the shell shows under the page title; assigning it pushes the new text out.
signal status_changed(text: String)
## The shown inventory (a session haul or the bound stock) changed — the shell refreshes the strip.
signal inventory_changed()
## The [method actions] list changed (e.g. a mode toggle relabelled a button) — the shell rebuilds them.
signal actions_changed()
## The stage asked the shell to drill into the next screen (e.g. an Encounter portrait opening that
## combatant's loadout in the Loadout screen), passing the [StarshipState] to inspect there. The stage names no
## screen — it just requests the drill and whose ship to show; the shell decides where.
signal drill_requested(starship: StarshipState)
## The stage asked its host to reopen the active encounter — the host owns the [Encounter], so it rebuilds it
## (a fresh fight) and the stage re-reads [code]GameSession.game_state.encounter[/code]. Used by the match's
## end-overlay Restart; a stage standing alone (no host) handles its own restart instead.
signal restart_requested()

var status_text: String = "":
	set(value):
		if value == status_text:
			return
		status_text = value
		status_changed.emit(value)

## Buttons the shell mounts at the right of the top bar (a stage's Reset, Mode, …); empty by default.
func actions() -> Array[MinigameAction]:
	var none: Array[MinigameAction] = []
	return none

## Compact entries for the always-visible inventory strip; an empty list hides the strip.
func inventory_chips() -> Array[InventoryChip]:
	var none: Array[InventoryChip] = []
	return none

## Richer content the strip reveals when expanded (or shows pinned open). Null means it can't expand.
## The shell reparents the returned control into the drawer and pulls it back out on teardown, so build
## it once and hand back the same instance.
func inventory_detail() -> Control:
	return null

## When true the detail is shown pinned open with no tap-to-expand — for a stage whose inventory IS the
## interface, like the Loadout screen's module grid.
func inventory_pinned() -> bool:
	return false
