class_name EncounterStarshipState
extends StarshipState
## A starship as it exists inside an encounter — its persistent [StarshipState] plus the per-fight state a
## starship only has while fighting: the resources it has banked (as [ResourcePool]s), the statuses on it (as
## [StatusStack]s — shield, dodge, stat buffs/debuffs), its turn's action budget, and the scoring offset in
## force. [EncounterState] owns one per combatant ([member EncounterState.player] / [member
## EncounterState.opponent]); the match's TURN_START rules write the budgets, capacity and offset here, and the
## grant rules bank into [member resources]. A bare [StarshipState] (a starship outside a fight) has none of
## this — resources and statuses are encounter-scoped.

## One slot per [MatchTile] kind. Sizes [member resources] / [member resource_maximums].
const RESOURCE_KINDS: int = 7

## The [AbilityResource] definition backing each [MatchTile] kind, index-aligned to kind — the kind each
## resource pool spends. Authored under res://data/ability_resources.
const _RESOURCE_DEFINITIONS: Array[AbilityResource] = [
	preload("res://data/ability_resources/combat.tres"),
	preload("res://data/ability_resources/propulsion.tres"),
	preload("res://data/ability_resources/science.tres"),
	preload("res://data/ability_resources/defense.tres"),
	preload("res://data/ability_resources/scrap.tres"),
	preload("res://data/ability_resources/warp.tres"),
	preload("res://data/ability_resources/damage.tres"),
]

## This starship's banked resources this encounter — one [ResourcePool] per [MatchTile] kind, index-aligned to
## kind, each pool's [member ResourcePool.amount] the count banked of that kind. What the portrait readouts show
## and abilities spend. Grown by [method add_resource] on a match, spent by [method spend_resource].
@export var resources: Array[ResourcePool] = []
## The most of each kind this starship may hold, index-aligned to kind. Zero (or an absent slot) means unlimited —
## the default, so banking is unbounded until a [ResourceCapacityRule] sets a ceiling at turn start.
@export var resource_maximums: PackedInt32Array = PackedInt32Array()
## The live statuses on this starship this encounter — shield, dodge, stat buffs/debuffs — each a [StatusStack]
## pairing a [Status] with its current count. The combat code reads and writes these in place; a status's
## [Modifier]s fold into [method EncounterState.effective_stats]. Encounter-scoped, fresh per fight.
@export var statuses: Array[StatusStack] = []
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
	# Reference arrays are rebuilt fresh per instance so two starships never share one pool list or status list
	# (an exported array default can be shared). A .tres load overwrites these right after _init with its data.
	resources = _fresh_resource_pools()
	statuses = []
	if resource_maximums.is_empty():
		resource_maximums.resize(RESOURCE_KINDS)

# One zeroed [ResourcePool] per kind, index-aligned, each bound to its [AbilityResource] definition.
func _fresh_resource_pools() -> Array[ResourcePool]:
	var pools: Array[ResourcePool] = []
	for kind: int in RESOURCE_KINDS:
		var pool := ResourcePool.new()
		pool.resource = _RESOURCE_DEFINITIONS[kind]
		pool.amount = 0
		pools.append(pool)
	return pools

## Wraps [param source]'s persistent starship data in an encounter-scoped state ready to bank resources. Shares the
## source's base stats / loadout / ruleset / abilities (the encounter only reads them); the new state carries its
## own fresh, zeroed resource pools and empty statuses. Used by [method Encounter.create] to build the two combatants.
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

## The [ResourcePool] backing [param resource] (matched by the resource's name), or null when this starship has
## no pool for it. The pools are still index-aligned to [member StarshipResource.tile_kind] (their order comes
## from [constant _RESOURCE_DEFINITIONS]), but lookup goes by name so callers reference resources, not indices.
func _pool_for(resource: StarshipResource) -> ResourcePool:
	if resource == null:
		return null
	for pool: ResourcePool in resources:
		if pool != null and pool.resource != null and pool.resource.name == resource.name:
			return pool
	return null

## This starship's banked count of [param resource] (zero when it has no pool for it).
func resource_of(resource: StarshipResource) -> int:
	var pool: ResourcePool = _pool_for(resource)
	return pool.amount if pool != null else 0

## Banks [param amount] of [param resource], clamped to this starship's capacity for it (a zero/absent maximum
## is unlimited). A non-positive amount or an unknown resource is a no-op.
func add_resource(resource: StarshipResource, amount: int) -> void:
	var pool: ResourcePool = _pool_for(resource)
	if amount <= 0 or pool == null:
		return
	var kind: int = resource.tile_kind
	var total: int = pool.amount + amount
	var maximum: int = resource_maximums[kind] if kind >= 0 and kind < resource_maximums.size() else 0
	pool.amount = total if maximum <= 0 else mini(total, maximum)

## Spends [param amount] of [param resource] (never below zero).
func spend_resource(resource: StarshipResource, amount: int) -> void:
	var pool: ResourcePool = _pool_for(resource)
	if amount <= 0 or pool == null:
		return
	pool.amount = maxi(0, pool.amount - amount)

## Sets this starship's per-kind capacity from [param maximums] (index-aligned to kind; zero/absent is unlimited).
## A resource already banked above a new ceiling is clamped down to it.
func set_resource_maximums(maximums: PackedInt32Array) -> void:
	for kind: int in resource_maximums.size():
		var maximum: int = maximums[kind] if kind < maximums.size() else 0
		resource_maximums[kind] = maxi(0, maximum)
		if maximum > 0 and kind < resources.size():
			resources[kind].amount = mini(resources[kind].amount, maximum)

## This starship's stack count of the status named [param status_name] (zero when it has no such status).
func status_count(status_name: StringName) -> int:
	for stack: StatusStack in statuses:
		if stack != null and stack.status != null and stack.status.name == status_name:
			return stack.count
	return 0

## Sets the stack count of [param status] to [param count], matched by the status's name — updating the live
## stack, or adding one when absent. A zero or negative count is kept (a depleted shield reads zero, a net
## debuff reads negative); stacks are not auto-removed here.
func set_status(status: Status, count: int) -> void:
	if status == null:
		return
	for stack: StatusStack in statuses:
		if stack != null and stack.status != null and stack.status.name == status.name:
			stack.count = count
			return
	if count != 0:
		var stack := StatusStack.new()
		stack.status = status
		stack.count = count
		statuses.append(stack)

## Adds [param delta] to the stack count of [param status] (matched by name), applying it when absent.
func add_status(status: Status, delta: int) -> void:
	if status == null:
		return
	set_status(status, status_count(status.name) + delta)

## Folds every active status's [Modifier]s into [param into] by stat name — the buff/debuff layer over base
## stats. Each ADD modifier shifts its stat by amount × stack count; the game-side stand-in for the effect
## engine's modifier pass.
func add_status_modifiers(into: StarshipStats) -> void:
	for stack: StatusStack in statuses:
		if stack == null or stack.status == null:
			continue
		for modifier: Modifier in stack.status.modifiers:
			if modifier == null or modifier.operation != Modifier.Operation.ADD:
				continue
			var delta: int = int(modifier.amount) * stack.count
			into.set_stat(modifier.stat, into.get_stat(modifier.stat) + delta)

## Spends one of this turn's actions (never below zero).
func consume_action() -> void:
	actions_remaining = maxi(0, actions_remaining - 1)

## Whether this starship has a move left this turn.
func has_actions_left() -> bool:
	return actions_remaining > 0
