class_name MatchAbility
extends Resource
## One ability button below the board: spend matched tiles to run one or more effects. Costs and effects are
## both lists, so an ability can charge several tile kinds and do several things — or just one of each, the
## common case. Nothing here is coupled: an ability is not tied to a single cost, a single effect, an effect
## that has an amount, or any turn behavior. Author a `.tres` per ability (or build the standard set with
## [method make]). Abilities belong to the starship — its hull kit and modules — not the match: see
## [member StarshipState.abilities] and [member ModuleBlueprint.abilities].

## Shown on the button under the cost. Flavor it toward the cost tiles and the effects.
@export var ability_name: String = "Ability"
## What using the ability costs: a list of [AbilityCost] (tile kind + amount). Every cost must be affordable
## to use it; using it spends each one. An empty list is a free ability.
@export var costs: Array[AbilityCost] = []
## What using the ability does: a list of [AbilityEffect], run in order. Each effect carries only its own
## parameters — there is no shared magnitude, so an effect with no amount (a [DodgeEffect]) is natural.
@export var effects: Array[AbilityEffect] = []

## Builds an ability with a single cost and a single effect — the common case, for code-built defaults
## and tests. For multi-cost or multi-effect abilities, assign [member costs]/[member effects] directly.
static func make(display_name: String, cost: AbilityCost, effect: AbilityEffect) -> MatchAbility:
	var ability := MatchAbility.new()
	ability.ability_name = display_name
	if cost != null:
		ability.costs = [cost]
	if effect != null:
		ability.effects = [effect]
	return ability

## A one-line description of what using the ability does, for the button tooltip — each effect's own line,
## joined. Empty when the ability has no effects.
func describe() -> String:
	var parts: Array[String] = []
	for effect: AbilityEffect in effects:
		if effect != null:
			parts.append(effect.describe())
	return ", ".join(parts)
