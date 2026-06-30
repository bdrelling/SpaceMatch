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

## One slot per [MatchTile] kind. Sizes [member Entity.resources] / [member resource_maximums].
const RESOURCE_KINDS: int = 7

## The [AbilityResource] definition backing each [MatchTile] kind, index-aligned to kind — the kind each
## resource pool spends. Authored under res://data/ability_resources.
const _RESOURCE_DEFINITIONS: Array[AbilityResource] = [
	preload("res://data/ability_resources/combat.tres"),
	preload("res://data/ability_resources/propulsion.tres"),
	preload("res://data/ability_resources/science.tres"),
	preload("res://data/ability_resources/shields.tres"),
	preload("res://data/ability_resources/scrap.tres"),
	preload("res://data/ability_resources/warp.tres"),
	preload("res://data/ability_resources/damage.tres"),
]

## The persistent starship this combatant fights as — the owner of its loadout, base stats, ruleset, abilities,
## and derived max health. The combatant reads these through it; combat mutations land on the combatant's own
## [member Entity.current_stats] / [member Entity.statuses] / [member Entity.resources], never on the starship.
@export var starship: StarshipState

## The side this combatant fights on, for future 2v2 grouping — combatants sharing a team are allies. In 1v1
## it mirrors [member Entity.id] (player 0, opponent 1); the engine never reads it, it's a game-side field.
@export var team: int = 0

## The most of each kind this combatant may hold, index-aligned to kind. Zero (or an absent slot) means
## unlimited — the default, so banking is unbounded until a [ResourceCapacityRule] sets a ceiling at turn start.
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
		# Live stats start as a copy of the effective profile; health is the live hull and depletes from here.
		combatant.current_stats = source.effective_stats()
		combatant.current_stats.set_stat(Stats.health, source.health)
	return combatant

## Persists this encounter's outcome back onto the fight [member starship] at the encounter's end. The combat
## state lives on the combatant (its [member Entity.current_stats]); this is the seam where a finished fight
## writes anything durable back. Near-empty for now — health is encounter-scoped and a fresh fight reseeds it.
func commit() -> void:
	if starship != null:
		starship.health = health()

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
## no pool for it. The pools are still index-aligned to [member StarshipResource.id] (their order comes
## from [constant _RESOURCE_DEFINITIONS]), but lookup goes by name so callers reference resources, not indices.
func _pool_for(resource: StarshipResource) -> ResourcePool:
	if resource == null:
		return null
	for pool: ResourcePool in resources:
		if pool != null and pool.resource != null and pool.resource.name == resource.name:
			return pool
	return null

## This combatant's banked count of [param resource] (zero when it has no pool for it).
func resource_of(resource: StarshipResource) -> int:
	var pool: ResourcePool = _pool_for(resource)
	return pool.amount if pool != null else 0

## Banks [param amount] of [param resource], clamped to this combatant's capacity for it (a zero/absent maximum
## is unlimited). A non-positive amount or an unknown resource is a no-op.
func add_resource(resource: StarshipResource, amount: int) -> void:
	var pool: ResourcePool = _pool_for(resource)
	if amount <= 0 or pool == null:
		return
	var kind: int = resource.id
	var total: int = pool.amount + amount
	var maximum: int = resource_maximums[kind] if kind >= 0 and kind < resource_maximums.size() else 0
	pool.amount = total if maximum <= 0 else mini(total, maximum)

## Spends [param amount] of [param resource] (never below zero).
func spend_resource(resource: StarshipResource, amount: int) -> void:
	var pool: ResourcePool = _pool_for(resource)
	if amount <= 0 or pool == null:
		return
	pool.amount = maxi(0, pool.amount - amount)

## Sets this combatant's per-kind capacity from [param maximums] (index-aligned to kind; zero/absent is
## unlimited). A resource already banked above a new ceiling is clamped down to it. Mirrors the maximum onto each
## pool's own [member ResourcePool.maximum] so the engine's [method ResourceEngine.grant] honours it too.
func set_resource_maximums(maximums: PackedInt32Array) -> void:
	for kind: int in resource_maximums.size():
		var maximum: int = maximums[kind] if kind < maximums.size() else 0
		resource_maximums[kind] = maxi(0, maximum)
		if kind < resources.size():
			resources[kind].maximum = resource_maximums[kind]
			if maximum > 0:
				resources[kind].amount = mini(resources[kind].amount, maximum)

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
