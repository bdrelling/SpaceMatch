class_name Minigame
extends Control
## Base for every arcade stage: a self-contained board plus a small view-model the shell reads to fill
## its chrome. The minigame owns its board, canvas, and input; it never draws the title bar, tab bar, or
## inventory strip. It only exposes [member status_text], its [method actions], and its
## [method inventory_chips] / [method inventory_detail], and the [Arcade] shell renders them — so the
## same chrome frames every stage and a stage stays just its board and rules.

## The one-line status the shell shows under the page title; assigning it pushes the new text out.
signal status_changed(text: String)
## The shown inventory (a session haul or the bound stock) changed — the shell refreshes the strip.
signal inventory_changed()
## The [method actions] list changed (e.g. a mode toggle relabelled a button) — the shell rebuilds them.
signal actions_changed()

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
## interface, like outfitting's module grid.
func inventory_pinned() -> bool:
	return false
