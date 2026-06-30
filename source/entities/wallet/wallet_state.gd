class_name WalletState
extends Resource
## The player's currency data — scrap for now. Held directly on [GameState] (no wrapping node): serializes
## cleanly and can move whole onto a per-player object later (e.g. co-op) without touching callers.

## Emitted whenever the balance changes ([method earn] / [method spend]) — the HUD scrap counter listens
## on this to repaint. Named distinctly from [Resource]'s built-in `changed` signal.
signal scrap_changed()

@export var scrap: int = 0

## True when [param cost] scrap is affordable.
func can_afford(cost: int) -> bool:
	return scrap >= cost

## Deducts [param cost] and returns true; leaves the wallet untouched and returns false if short.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	scrap -= cost
	scrap_changed.emit()
	return true

## Adds [param amount] scrap. A non-positive amount is a no-op (no spurious [signal scrap_changed]).
func earn(amount: int) -> void:
	if amount <= 0:
		return
	scrap += amount
	scrap_changed.emit()
