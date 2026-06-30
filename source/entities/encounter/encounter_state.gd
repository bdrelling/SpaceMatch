class_name EncounterState
extends Resource
## The active encounter's slice of the game state — state only the encounter (the match-3 play
## screen) has, which the 3D game never reads. Null on [GameState] when no encounter is running.
## Lives under [member GameState.encounter], serialized with the one save.
##
## Holds the two [Combatant]s fighting it out — each an engine [Entity] wrapped around the starship it fights as,
## carrying its own live combat stats (health, the buff layer), statuses (shield, dodge, buffs/debuffs) and banked
## resources — and the turn/round counter the match advances after each move. Combat runs through the effect
## engine: damage flows through the [ModificationPipeline] (shield absorbs, dodge negates), statuses fold via
## [StatusModifiers], all driven by the one [member runtime] this state holds.

## A round is one turn per combatant.
const TURNS_PER_ROUND: int = 2

## How many tile kinds a combatant can bank as resources — one slot per [MatchTile] kind. Sizes the
## resource arrays; a fresh encounter starts them all at zero.
const RESOURCE_KINDS: int = 7

## The statuses combat stamps onto a combatant as data — preloaded so the encounter can apply them by reference.
const SHIELD: Status = preload("res://data/statuses/shield.tres")
const DODGE: Status = preload("res://data/statuses/dodge.tres")
const TARGET_LOCK: Status = preload("res://data/statuses/target_lock.tres")

## The two combatants — each a [Combatant] (an engine [Entity]) holding its banked resources, live combat stats
## and turn budget (see [method Encounter.create]). The player's wraps a clone of the persistent starship so
## combat damage and Debug edits stay on the fight copy; the opponent wraps its own starship, not a copy of the
## player's. Each owns its own health (a stat on its [member Entity.current_stats]). The two are told apart by
## identity (and by [member Entity.id]: the player's is 0, the opponent's 1) — there is no side enum.
@export var player: Combatant
## The opponent's combatant — its own default, distinct from the player's. Human-controlled for now; AI lands later.
@export var opponent: Combatant

## 1-based round counter.
@export var round_number: int = 1
## Which turn within the current round, 1..[constant TURNS_PER_ROUND]. Turn 1 is the player's, turn 2 the opponent's.
@export var turn_in_round: int = 1

# The one effect-engine runtime this encounter drives all combat through (damage pipeline, decay-on-hit, status
# folding). Built lazily on first use so a freshly loaded state has one; the host seeds its [member
# EffectRuntime.rng_seed] from the board RNG (see [method MatchGame.bind_session]).
var _runtime: EffectRuntime

## Each combatant's current and max health — read-throughs to the [Combatant] that owns them ([member player] /
## [member opponent]), kept as named pairs for the combat code and HUD. Current depletes from matched damage
## tiles (see [method deal_damage]); max is the starship's derived hull (see [method Combatant.max_health]).
var player_health: int:
	get: return health_of(player)
	set(value): _set_health(player, value)
var opponent_health: int:
	get: return health_of(opponent)
	set(value): _set_health(opponent, value)
var player_max_health: int:
	get: return max_health_of(player)
var opponent_max_health: int:
	get: return max_health_of(opponent)

## Cells currently disabled on each combatant's module grid, mapping a cell [Vector2i] to the turns of
## disable it has left (granted by Disruptor; see [method disable_cell]). A disabled cell deactivates the
## module covering it, so that module stops counting toward the starship's stat profile until it re-enables.
## Counted down one per turn by [method advance_turn].
@export var player_disabled_cells: Dictionary[Vector2i, int] = {}
@export var opponent_disabled_cells: Dictionary[Vector2i, int] = {}

## Each combatant's warp capacity — the bars their side of the meter holds before they can Jump (see
## [method can_jump]) to win outright. Granted by warp-core modules, so it's a copy of the starship's
## [member StarshipStats.warp_capacity]; the match seeds these at setup. Zero means that starship can't warp at all —
## no Jump, and the board spawns no warp tiles when neither side can warp. The two can differ (a six-bar core
## versus a four-bar one), which is why the capacities live per combatant rather than as one shared cap.
@export var player_warp_max: int = 0
@export var opponent_warp_max: int = 0

## The shared warp meter, signed: positive is the player's progress, negative the opponent's. Matching Warp
## tiles pushes it toward the mover's end ([method add_warp]). Encounter-scoped, so it starts at zero.
@export var warp: int = 0
## Quick Match runs warp as a two-way tug: the opponent collects toward their own Jump, so the meter can go
## negative and they win at -[member opponent_warp_max]. Campaign leaves this false — the opponent's warp only
## drains the player's (floored at zero) and can never win.
@export var warp_tug: bool = false
## The combatant who Jumped (filled their warp and cashed it in), or null if none. Decides a warp victory.
@export var warp_winner: Combatant

## The one [EffectRuntime] all combat resolves through — built on first access with an [AutoChooser] (1v1 needs
## no interactive picker) and the live status catalog. The host seeds its seed from the board RNG.
func runtime() -> EffectRuntime:
	if _runtime == null:
		_runtime = EffectRuntime.new()
		_runtime.chooser = AutoChooser.new()
		_runtime.status_catalog = _status_catalog()
	return _runtime

# The status catalog the runtime resolves names through ([ApplyStatusAction] / [RemoveStatusAction]): every
# authored [Status] keyed by its name, from the live [Catalogs] autoload.
func _status_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	if Catalogs != null and Catalogs.statuses != null:
		for status: Status in Catalogs.statuses.entries():
			if status != null:
				catalog[status.name] = status
	return catalog

## The combatant whose turn it currently is — the player on turn 1 of the round, the opponent on turn 2.
func active_combatant() -> Combatant:
	return player if turn_in_round == 1 else opponent

## The combatant opposing [param combatant] — the target a mover's damage tiles hit. Returns the player for
## anything that isn't the player (so a null or stray reference resolves to the player's foe, the opponent).
func opponent_of(combatant: Combatant) -> Combatant:
	return opponent if combatant == player else player

## The two combatants as engine [Entity]s, [param combatant] first (its allies are itself, its opponents the
## other) — what the runtime's phase/hook calls take.
func _allies_of(combatant: Combatant) -> Array[Entity]:
	var entities: Array[Entity] = []
	if combatant != null:
		entities.append(combatant)
	return entities

func _opponents_of(combatant: Combatant) -> Array[Entity]:
	var entities: Array[Entity] = []
	var foe: Combatant = opponent_of(combatant)
	if foe != null:
		entities.append(foe)
	return entities

## [param combatant]'s current health — its live hull (0 if null).
func health_of(combatant: Combatant) -> int:
	return combatant.health() if combatant != null else 0

## [param combatant]'s max health — its starship's derived hull, the bar's cap (0 if null).
func max_health_of(combatant: Combatant) -> int:
	return combatant.max_health() if combatant != null else 0

## Sets [param combatant]'s current health, floored at zero. The combatant's stat is the source of truth.
func _set_health(combatant: Combatant, value: int) -> void:
	if combatant != null:
		combatant.set_health(maxi(0, value))

## [param combatant]'s current shield — the live [code]shield[/code] pool stat the shield status's AbsorbStep soaks into.
func shield_of(combatant: Combatant) -> int:
	return combatant.current_stats.get_stat(Stats.block) if combatant != null and combatant.current_stats != null else 0

## Grants [param combatant] [param amount] more shield (the Shields ability) — adds to the shield pool stat and keeps
## the [code]shield[/code] status applied so its AbsorbStep is in the damage pipeline.
func add_shield(combatant: Combatant, amount: int) -> void:
	if amount <= 0:
		return
	_set_shield(combatant, shield_of(combatant) + amount)

## [param combatant]'s shield pool, in sync: writes the [code]shield[/code] stat and mirrors the [code]shield[/code]
## status (present with that count while shield remains, removed at zero) so the AbsorbStep stays collected.
func _set_shield(combatant: Combatant, value: int) -> void:
	if combatant == null or combatant.current_stats == null:
		return
	var amount: int = maxi(0, value)
	combatant.current_stats.set_stat(Stats.block, amount)
	if amount > 0:
		combatant.set_status(SHIELD, amount)
	else:
		StatusEngine.remove_status(combatant, &"shield")

## Whether [param combatant] is set to dodge the next attack against them (holds the [code]dodge[/code] status).
func dodge_of(combatant: Combatant) -> bool:
	return combatant != null and combatant.status_count(&"dodge") > 0

## Arms or clears [param combatant]'s dodge (Evasive Maneuvers arms it; the next attack consumes it).
func set_dodge(combatant: Combatant, on: bool) -> void:
	if combatant != null:
		combatant.set_status(DODGE, 1 if on else 0)

## Applies [param count] stacks of [param status] to [param combatant] — a buff or debuff. A stat-modifying status
## shifts that combatant's [method effective_stats]; it stacks for the encounter (Target Lock's +weapons lands
## this way).
func add_status(combatant: Combatant, status: Status, count: int) -> void:
	if combatant != null:
		combatant.add_status(status, count)

## [param combatant]'s effective stats: its permanent module-grid profile ([param base], supplied by the host since
## the starship owns the grid) with this encounter's active-status [Modifier]s folded on top by the engine's
## [StatusModifiers]. The stats combat consumes — the weapons stat bonuses the hit, the four colored stats the
## resource they bank.
func effective_stats(combatant: Combatant, base: StarshipStats) -> StarshipStats:
	var total := StarshipStats.new()
	total.add(base)
	if combatant != null:
		StatusModifiers.apply(combatant, total)
	return total

## The cells currently disabled on [param combatant]'s grid — each deactivates the module covering it.
func disabled_cells_of(combatant: Combatant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _disabled_map(combatant):
		result.append(cell)
	return result

## Disables [param cell] on [param combatant]'s grid for [param turns] turns — the module covering it stops counting
## until the disable expires. Refreshes to the longer remaining if the cell is already disabled. Counted down one
## per turn by [method advance_turn], so a value of N keeps the cell disabled through the next N turn changes. A
## non-positive duration is a no-op (the Disruptor ability — this stays on the game-side path, not the engine).
func disable_cell(combatant: Combatant, cell: Vector2i, turns: int) -> void:
	if turns <= 0:
		return
	var map: Dictionary[Vector2i, int] = _disabled_map(combatant)
	var current: int = map[cell] if map.has(cell) else 0
	map[cell] = maxi(current, turns)

func _disabled_map(combatant: Combatant) -> Dictionary[Vector2i, int]:
	return player_disabled_cells if combatant == player else opponent_disabled_cells

# Counts every disabled cell down one turn and re-enables those that reach zero. Run once per turn change.
func _tick_disabled_cells() -> void:
	for combatant: Combatant in [player, opponent]:
		var map: Dictionary[Vector2i, int] = _disabled_map(combatant)
		for cell: Vector2i in map.keys():
			map[cell] -= 1
			if map[cell] <= 0:
				map.erase(cell)

## Applies [param amount] of incoming damage to [param target], through the effect engine: a dodge negates it
## whole (the engine consumes the dodge stack on the [WhenHitHook]) and leaves shield untouched, otherwise the
## hit runs through the [ModificationPipeline] — the target's [code]shield[/code] AbsorbStep soaks before health.
## Returns the damage that reached health, or [code]-1[/code] if it was dodged. A non-positive amount is a no-op
## (returns 0).
func deal_damage(target: Combatant, amount: int) -> int:
	if amount <= 0:
		return 0
	if target == null or target.current_stats == null:
		return 0
	var source: Combatant = opponent_of(target)
	# Dodge negates the whole hit and is spent. Routing the spend through the engine: raise WhenHitHook on the
	# target so its dodge status's TriggerDecayRule consumes a stack. (Bare-hook raise completes synchronously —
	# dodge carries no hook-triggered effects, only the decay rule.) Shield is left untouched, as before.
	if dodge_of(target):
		runtime().raise_hook(target, _allies_of(target), _opponents_of(target), WhenHitHook.new(), source)
		return -1
	# Not dodging: run the damage through the pipeline so shield's AbsorbStep soaks it before it reaches health.
	var modification := Modification.new()
	modification.source = source
	modification.target = target
	modification.stat = Stats.health
	modification.amount = amount
	modification.tag = &"damage"
	var context := ResolutionContext.create(modification.source, _opponents_of(target), _allies_of(target), 0, runtime().chooser)
	context.status_catalog = runtime().status_catalog
	var to_health: int = ModificationPipeline.resolve(modification, context)
	if to_health > 0:
		_set_health(target, health_of(target) - to_health)
	# The AbsorbStep drained the shield stat in place; resync the shield status to match (drop it at zero).
	_sync_shield_status(target)
	# Mark that a hit landed so any further "when hit" reactions fire (dodge already handled above).
	runtime().raise_hook(target, _allies_of(target), _opponents_of(target), WhenHitHook.new(), modification.source)
	return to_health

# Re-points the [code]shield[/code] status's count at the live shield pool stat the AbsorbStep just changed, so
# the badge/stack count stays in step — removing the status when the pool is empty.
func _sync_shield_status(combatant: Combatant) -> void:
	if combatant == null or combatant.current_stats == null:
		return
	var pool: int = combatant.current_stats.get_stat(Stats.block)
	if pool > 0:
		combatant.set_status(SHIELD, pool)
	else:
		StatusEngine.remove_status(combatant, &"shield")

## Whether the encounter has been decided — a combatant Jumped, or one is out of health.
func is_over() -> bool:
	return warp_winner != null or player_health <= 0 or opponent_health <= 0

## The combatant that lost. Only meaningful once [method is_over] is true: the one who didn't Jump if there was a
## warp victory, else the one out of health.
func defeated() -> Combatant:
	if warp_winner != null:
		return opponent_of(warp_winner)
	return player if player_health <= 0 else opponent

## [param combatant]'s filled warp bars — the side of the shared meter in their favor (0 if they're behind).
func warp_of(combatant: Combatant) -> int:
	return maxi(0, warp) if combatant == player else maxi(0, -warp)

## [param combatant]'s warp capacity — the bars their side holds before they can Jump.
func warp_max_of(combatant: Combatant) -> int:
	return player_warp_max if combatant == player else opponent_warp_max

## Adds [param bars] of warp for [param combatant]: the player's pushes the meter up, the opponent's down.
## Clamps to each side's own capacity; without a tug (Campaign) it never drops below zero, so the opponent's
## warp only cancels the player's progress.
func add_warp(combatant: Combatant, bars: int) -> void:
	if bars <= 0:
		return
	warp += bars if combatant == player else -bars
	var low: int = -opponent_warp_max if warp_tug else 0
	warp = clampi(warp, low, player_warp_max)

## Whether [param combatant] has filled their warp and may Jump. The player can at a full meter; the opponent
## only in a tug (Quick Match).
func can_jump(combatant: Combatant) -> bool:
	if combatant == player:
		return player_warp_max > 0 and warp >= player_warp_max
	return warp_tug and opponent_warp_max > 0 and warp <= -opponent_warp_max

## [param combatant] Jumps: expends the warp and wins the encounter (see [method defeated]). A no-op when they
## can't yet.
func jump(combatant: Combatant) -> void:
	if not can_jump(combatant):
		return
	warp_winner = combatant
	warp = 0

## Ends the active combatant's turn: advances to the next turn, rolling into the next round once both
## combatants have moved.
func advance_turn() -> void:
	turn_in_round += 1
	if turn_in_round > TURNS_PER_ROUND:
		turn_in_round = 1
		round_number += 1
	# A dodge guards only the opponent's turn that follows it. Once the owner's own turn comes back around,
	# it expires (used or not) so it can't linger forever.
	set_dodge(active_combatant(), false)
	# Disabled cells count toward re-enabling each turn; modules whose cells expire start counting again.
	_tick_disabled_cells()
