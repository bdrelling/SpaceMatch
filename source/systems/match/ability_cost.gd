class_name AbilityCost
extends Resource
## One tile cost in a [MatchAbility]'s price: spend [member amount] matched tiles of [member resource]. An
## ability's [member MatchAbility.costs] is a list of these, so one ability can charge several resources at
## once — or none, for a free ability. Every cost must be affordable to use the ability; using it spends each.

## The [StarshipResource] this cost is paid in (combat / propulsion / science / defense). Its
## [member StarshipResource.tile_kind] is the board tile that banks it.
@export var resource: StarshipResource
## How many matched tiles of [member resource] one use spends.
@export var amount: int = 5

## Builds a cost in one line — for code-built defaults and tests.
static func make(cost_resource: StarshipResource, tile_amount: int) -> AbilityCost:
	var cost := AbilityCost.new()
	cost.resource = cost_resource
	cost.amount = tile_amount
	return cost
