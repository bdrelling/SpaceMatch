class_name AbilityCost
extends Resource
## One tile cost in a [MatchAbility]'s price: spend [member amount] matched tiles of [member kind]. An
## ability's [member MatchAbility.costs] is a list of these, so one ability can charge several tile kinds at
## once — or none, for a free ability. Every cost must be affordable to use the ability; using it spends each.

## The [MatchTile] kind this cost is paid in (red/yellow/green/blue = 0/1/2/3).
@export var kind: int = 0
## How many matched tiles of [member kind] one use spends.
@export var amount: int = 5

## Builds a cost in one line — for [method MatchRules.default] and tests.
static func make(tile_kind: int, tile_amount: int) -> AbilityCost:
	var cost := AbilityCost.new()
	cost.kind = tile_kind
	cost.amount = tile_amount
	return cost
