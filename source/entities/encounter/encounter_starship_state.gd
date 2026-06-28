class_name EncounterStarshipState
extends StarshipState
## A starship as it exists inside an encounter — its persistent [StarshipState] plus the per-fight state a
## starship only has while fighting: the resources it has banked, their optional capacity, its turn's action
## budget, and the scoring offset in force. [EncounterState] owns one per combatant ([member
## EncounterState.player] / [member EncounterState.opponent]); the match's TURN_START rules write the budgets,
## capacity and offset here, and the grant rules bank into [member resources]. A bare [StarshipState] (a starship
## outside a fight) has none of this — resources are encounter-scoped.

## One slot per [MatchTile] kind. Sizes [member resources] / [member resource_maximums].
const RESOURCE_KINDS: int = 7

## This starship's banked resources this encounter, per [MatchTile] kind — what the portrait readouts show and
## abilities spend. Grown by [method add_resource] on a match, spent by [method spend_resource].
@export var resources: PackedInt32Array = PackedInt32Array()
## The most of each kind this starship may hold, index-aligned to kind. Zero (or an absent slot) means unlimited —
## the default, so banking is unbounded until a [ResourceCapacityRule] sets a ceiling at turn start.
@export var resource_maximums: PackedInt32Array = PackedInt32Array()
## Board moves this starship has left this turn. Refilled at turn start by [ActionBudgetRule] to its
## actions-per-turn, spent one per resolved move; the turn passes once it reaches zero. One is a single-move turn.
@export var actions_remaining: int = 1
## What using an ability does to this starship's turn — an [enum ActionBudgetRule.AbilityTurnCost] value, set at
## turn start by [ActionBudgetRule]. Default zero is [constant ActionBudgetRule.AbilityTurnCost.ENDS_TURN].
@export var ability_turn_cost: int = 0
## Subtracted from every match's reward this turn (floored at zero) — a match of N banks N minus this. Zero by
## default (a match of N banks N); set at turn start by [OffsetScoringRule].
@export var score_offset: int = 0

func _init() -> void:
	if resources.is_empty():
		resources.resize(RESOURCE_KINDS)
	if resource_maximums.is_empty():
		resource_maximums.resize(RESOURCE_KINDS)

## Wraps [param source]'s persistent starship data in an encounter-scoped state ready to bank resources. Shares the
## source's base stats / loadout / ruleset / abilities (the encounter only reads them); the new state carries its
## own fresh, zeroed resource tally. Used by [method Encounter.create] to build the two combatants.
static func for_combatant(source: StarshipState) -> EncounterStarshipState:
	var starship := EncounterStarshipState.new()
	if source != null:
		starship.name = source.name
		starship.base_stats = source.base_stats
		starship.loadout = source.loadout
		starship.health = source.health
		starship.selection_override = source.selection_override
		starship.ruleset = source.ruleset
		starship.abilities = source.abilities
	return starship

## This starship's banked count of [param kind] (zero for an unknown kind).
func resource_of(kind: int) -> int:
	return resources[kind] if kind >= 0 and kind < resources.size() else 0

## Banks [param amount] of [param kind], clamped to this starship's capacity for that kind (a zero/absent maximum
## is unlimited). A non-positive amount or an unknown kind is a no-op.
func add_resource(kind: int, amount: int) -> void:
	if amount <= 0 or kind < 0 or kind >= resources.size():
		return
	var total: int = resources[kind] + amount
	var maximum: int = resource_maximums[kind] if kind < resource_maximums.size() else 0
	resources[kind] = total if maximum <= 0 else mini(total, maximum)

## Spends [param amount] of [param kind] (never below zero).
func spend_resource(kind: int, amount: int) -> void:
	if amount <= 0 or kind < 0 or kind >= resources.size():
		return
	resources[kind] = maxi(0, resources[kind] - amount)

## Sets this starship's per-kind capacity from [param maximums] (index-aligned to kind; zero/absent is unlimited).
## A resource already banked above a new ceiling is clamped down to it.
func set_resource_maximums(maximums: PackedInt32Array) -> void:
	for kind: int in resource_maximums.size():
		var maximum: int = maximums[kind] if kind < maximums.size() else 0
		resource_maximums[kind] = maxi(0, maximum)
		if maximum > 0 and kind < resources.size():
			resources[kind] = mini(resources[kind], maximum)

## Spends one of this turn's actions (never below zero).
func consume_action() -> void:
	actions_remaining = maxi(0, actions_remaining - 1)

## Whether this starship has a move left this turn.
func has_actions_left() -> bool:
	return actions_remaining > 0
