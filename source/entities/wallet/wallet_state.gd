class_name WalletState
extends Resource
## The player's currency data — scrap for now, held as a [CurrencyResource] [ResourcePool] so scrap is one number
## owned by the wallet (its persistence and view), not duplicated on a combatant. Held directly on [GameState]; a
## game-side [CurrencyAmount] reads a balance off it through the resolution context, so the effect engine never
## learns what a wallet is.

## Emitted whenever a balance changes ([method earn] / [method spend]) — the HUD scrap counter listens on this to
## repaint. Named distinctly from [Resource]'s built-in `changed` signal.
signal scrap_changed

const _SCRAP: CurrencyResource = preload("res://data/currencies/scrap.tres")

## The currency pools the wallet holds (scrap for now), each a [CurrencyResource] amount. Persisted with the game.
@export var resources: Array[ResourcePool] = []

## The player's scrap balance — the amount in the wallet's scrap pool.
var scrap: int:
	get:
		return amount_of(_SCRAP)


func _init() -> void:
	# A fresh wallet starts with a zeroed scrap pool; a .tres load overwrites this right after.
	if resources.is_empty():
		var pool := ResourcePool.new()
		pool.resource = _SCRAP
		resources.append(pool)


## This wallet's balance of [param currency] (zero when it holds no pool for it), matched by name — the game-side
## read a [CurrencyAmount] resolves through.
func amount_of(currency: EntityResource) -> int:
	var pool: ResourcePool = _pool_for(currency)
	return pool.amount if pool != null else 0


## True when [param cost] scrap is affordable.
func can_afford(cost: int) -> bool:
	return scrap >= cost


## Deducts [param cost] scrap and returns true; leaves the wallet untouched and returns false if short.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	var pool: ResourcePool = _pool_for(_SCRAP)
	if pool != null:
		pool.amount = maxi(0, pool.amount - cost)
		scrap_changed.emit()
	return true


## Adds [param amount] scrap. A non-positive amount is a no-op (no spurious [signal scrap_changed]).
func earn(amount: int) -> void:
	if amount <= 0:
		return
	var pool: ResourcePool = _pool_for(_SCRAP)
	if pool != null:
		pool.amount += amount
		scrap_changed.emit()


# The pool backing [param currency] (matched by the resource's name), or null when the wallet holds none.
func _pool_for(currency: EntityResource) -> ResourcePool:
	if currency == null:
		return null
	for pool: ResourcePool in resources:
		if pool != null and pool.resource != null and pool.resource.name == currency.name:
			return pool
	return null
