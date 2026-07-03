class_name Combatant
extends Entity
## A starship fighting in an encounter, modeled as an engine [Entity]: it carries the live combat state the
## effect engine acts on — [member Entity.current_stats] (health and the temporary buff layer), [member
## Entity.statuses] (shield, dodge, stat buffs/debuffs as [StatusStack]s), and [member Entity.resources] (the
## banked match resources as [ResourcePool]s) — wrapped around the persistent [member starship] it fights as.
## [EncounterState] owns one per side ([member EncounterState.player] / [member EncounterState.opponent]); the
## match's TURN_START rules write the budgets, capacity and offset here, the grant rules bank into [member
## resources], and damage flows through [member current_stats]. A bare [StarshipState] (a starship outside a
## fight) has none of this — combat state is encounter-scoped.

## One pool per ability resource this combatant banks. Sizes [member Entity.resources] / [member
## resource_maximums]. Not the same as the tile-kind count — damage is a tile (no resource), and scrap is a
## wallet [CurrencyResource] (banked on [WalletState], not here), so neither has a combatant pool.
const RESOURCE_COUNT: int = 5

## The [AbilityResource] definition behind each pool, index-aligned to the pool array (its own order, not tile
## kind). Authored under res://data/ability_resources; capacity is keyed off this position, not a resource id.
const _RESOURCE_DEFINITIONS: Array[AbilityResource] = [
	preload("res://data/ability_resources/combat.tres"),
	preload("res://data/ability_resources/propulsion.tres"),
	preload("res://data/ability_resources/science.tres"),
	preload("res://data/ability_resources/shields.tres"),
	preload("res://data/ability_resources/warp.tres"),
]

## The persistent starship this combatant fights as — the owner of its loadout, base stats, ruleset, abilities,
## and derived max health. The combatant reads these through it; combat mutations land on the combatant's own
## [member Entity.current_stats] / [member Entity.statuses] / [member Entity.resources], never on the starship.
@export var starship: StarshipState

## The side this combatant fights on, for future 2v2 grouping — combatants sharing a team are allies. In 1v1
## it mirrors [member Entity.id] (player 0, opponent 1); the engine never reads it, it's a game-side field.
@export var team: int = 0

## The most of each resource this combatant may hold, index-aligned to the pool array ([constant
## _RESOURCE_DEFINITIONS] order). Zero (or an absent slot) means unlimited — the default, so banking is unbounded
## until a [ResourceCapacityRule] sets a ceiling at turn start.
@export var resource_maximums: PackedInt32Array = PackedInt32Array()
## Board moves this combatant has left this turn. Refilled at turn start by [ActionBudgetRule] to its
## actions-per-turn, spent one per resolved move; the turn passes once it reaches zero. One is a single-move turn.
@export var actions_remaining: int = 1
## What using an ability does to this combatant's turn — an [enum ActionBudgetRule.AbilityTurnCost] value, set at
## turn start by [ActionBudgetRule]. Default zero is [constant ActionBudgetRule.AbilityTurnCost.ENDS_TURN].
@export var ability_turn_cost: int = 0
## Subtracted from every match's reward this turn (floored at zero) — a match of N banks N minus this. Zero by
## default (a match of N banks N); set at turn start by [OffsetScoringRule].
@export var score_offset: int = 0


func _init() -> void:
	# Reference arrays are rebuilt fresh per instance so two combatants never share one pool list or status list
	# (an exported array default can be shared). A .tres load overwrites these right after _init with its data.
	resources = _fresh_resource_pools()
	statuses = []
	current_stats = StarshipStats.new()
	if resource_maximums.is_empty():
		resource_maximums.resize(RESOURCE_COUNT)


# One zeroed [ResourcePool] per resource, index-aligned to [constant _RESOURCE_DEFINITIONS].
func _fresh_resource_pools() -> Array[ResourcePool]:
	var pools: Array[ResourcePool] = []
	for index: int in RESOURCE_COUNT:
		var pool := ResourcePool.new()
		pool.resource = _RESOURCE_DEFINITIONS[index]
		pool.amount = 0
		pools.append(pool)
	return pools


## Builds a combatant fighting as [param source] — its [Entity] fields seeded from the starship: [member
## Entity.base_stats] from the starship's effective stats, live [member Entity.current_stats] starting at full
## (health at [method StarshipState.max_health]), and fresh zeroed resource pools / empty statuses. Shares the
## source's loadout / ruleset / abilities (the encounter only reads them). [param combatant_id] is the stable
## [member Entity.id] telling the two combatants apart — 0 for the player, 1 for the opponent — and doubles as
## the serializable tile-ownership marker on a shared board. [param combatant_team] is the side it fights on
## (for future 2v2 grouping); in 1v1 it matches the id. Used by [method Encounter.create].
static func create(source: StarshipState, combatant_id: int = 0, combatant_team: int = 0) -> Combatant:
	var combatant := Combatant.new()
	combatant.id = combatant_id
	combatant.team = combatant_team
	combatant.starship = source
	if source != null:
		combatant.base_stats = source.effective_stats()
		# Live stats start as a copy of the effective profile: the health pool carries both the current hull and its
		# max straight from the authored stats, so the bar begins full and capped, and depletes from here.
		combatant.current_stats = source.effective_stats()
	return combatant


## Persists this encounter's outcome back onto the fight [member starship] at the encounter's end. The combat
## state lives on the combatant (its [member Entity.current_stats]); this is the seam where a finished fight
## writes anything durable back. A no-op for now — health is encounter-scoped and a fresh fight reseeds it full.
func commit() -> void:
	pass


## This combatant's live hull — the health stat on its [member Entity.current_stats].
func health() -> int:
	return current_stats.get_stat(Stats.health) if current_stats != null else 0


## Sets this combatant's live hull (floored at zero) on its [member Entity.current_stats].
func set_health(value: int) -> void:
	if current_stats != null:
		current_stats.set_stat(Stats.health, maxi(0, value))


## This combatant's max hull — its starship's derived health (base stat plus hull modules). The bar's cap.
func max_health() -> int:
	return starship.max_health() if starship != null else 0


## The [ResourcePool] backing [param resource] (matched by the resource's name), or null when this combatant has
## no pool for it. Lookup goes by name so callers reference resources, not indices.
func _pool_for(resource: AbilityResource) -> ResourcePool:
	if resource == null:
		return null
	for pool: ResourcePool in resources:
		if pool != null and pool.resource != null and pool.resource.name == resource.name:
			return pool
	return null


## This combatant's banked count of [param resource] (zero when it has no pool for it).
func resource_of(resource: AbilityResource) -> int:
	var pool: ResourcePool = _pool_for(resource)
	return pool.amount if pool != null else 0


## Banks [param amount] of [param resource], clamped to the pool's own capacity (a zero maximum is unlimited —
## [method set_resource_maximums] mirrors the per-pool ceiling here). A non-positive amount or unknown resource is
## a no-op. Keyed by the pool, not a resource id, so it no longer assumes the resource carries a tile kind.
func add_resource(resource: AbilityResource, amount: int) -> void:
	var pool: ResourcePool = _pool_for(resource)
	if amount <= 0 or pool == null:
		return
	var total: int = pool.amount + amount
	pool.amount = total if pool.maximum <= 0 else mini(total, pool.maximum)


## Spends [param amount] of [param resource] (never below zero).
func spend_resource(resource: AbilityResource, amount: int) -> void:
	var pool: ResourcePool = _pool_for(resource)
	if amount <= 0 or pool == null:
		return
	pool.amount = maxi(0, pool.amount - amount)


## Sets this combatant's per-pool capacity from [param maximums] (index-aligned to the pool array; zero/absent is
## unlimited). A resource already banked above a new ceiling is clamped down to it. Mirrors the maximum onto each
## pool's own [member ResourcePool.maximum] so the engine's [method ResourceEngine.grant] honours it too.
func set_resource_maximums(maximums: PackedInt32Array) -> void:
	for index: int in resource_maximums.size():
		var maximum: int = maximums[index] if index < maximums.size() else 0
		resource_maximums[index] = maxi(0, maximum)
		if index < resources.size():
			resources[index].maximum = resource_maximums[index]
			if maximum > 0:
				resources[index].amount = mini(resources[index].amount, maximum)


## This combatant's stack count of the status named [param status_name] (zero when it has no such status).
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


## Spends one of this turn's actions (never below zero).
func consume_action() -> void:
	actions_remaining = maxi(0, actions_remaining - 1)


## Whether this combatant has a move left this turn.
func has_actions_left() -> bool:
	return actions_remaining > 0
