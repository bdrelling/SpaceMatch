class_name EncounterState
extends Resource
## The active encounter's slice of the game state — state only the encounter (the match-3 play
## screen) has, which the 3D game never reads. Null on [GameState] when no encounter is running.
## Lives under [member GameState.encounter], serialized with the one save.
##
## Holds the two ships fighting it out — the combatants whose own [member StarshipState.health] is the
## encounter's health, so the ship itself is the thing that's destroyed — and the turn/round counter that the
## match minigame advances after each move and shows in its top row.

## The two combatants. Turn 1 of a round is the player's, turn 2 the opponent's.
enum Combatant { PLAYER, OPPONENT }

## A round is one turn per combatant.
const TURNS_PER_ROUND: int = 2

## How many tile kinds a combatant can bank as resources — one slot per [MatchTile] kind. Sizes the
## resource arrays; a fresh encounter starts them all at zero.
const RESOURCE_KINDS: int = 7

## The two combatants — each an [EncounterStarshipState], the encounter-scoped form of a ship that also holds
## its banked resources and turn budget (see [method Encounter.create]). The player's is built from the
## persistent ship so combat damage and Debug edits stay on the fight copy; the opponent is its own ship, not a
## copy of the player's. Each owns its own [member StarshipState.health].
@export var player: EncounterStarshipState
## The opponent's ship — its own default, distinct from the player's. Human-controlled for now; AI lands later.
@export var opponent: EncounterStarshipState

## 1-based round counter.
@export var round_number: int = 1
## Which turn within the current round, 1..[constant TURNS_PER_ROUND].
@export var turn_in_round: int = 1

## Each combatant's current and max health — read-throughs to the ship that owns them ([member player] /
## [member opponent]), kept as named pairs for the combat code and HUD. Current depletes from matched damage
## tiles (see [method deal_damage]); max is the ship's derived hull (see [method StarshipState.max_health]).
var player_health: int:
	get: return health_of(Combatant.PLAYER)
	set(value): _set_health(Combatant.PLAYER, value)
var opponent_health: int:
	get: return health_of(Combatant.OPPONENT)
	set(value): _set_health(Combatant.OPPONENT, value)
var player_max_health: int:
	get: return max_health_of(Combatant.PLAYER)
var opponent_max_health: int:
	get: return max_health_of(Combatant.OPPONENT)

## Each combatant's shield — a buffer that absorbs damage before health (granted by the Shields ability).
@export var player_shield: int = 0
@export var opponent_shield: int = 0
## Whether a combatant will dodge (negate) the next attack against them (granted by Evasive Maneuvers).
@export var player_dodge: bool = false
@export var opponent_dodge: bool = false
## Each combatant's temporary stat layer — buffs and debuffs (e.g. Target Lock's +damage) stacked on top of
## the ship's permanent module-grid profile. [method effective_stats] combines the two into the stats combat
## reads. Encounter-scoped, so a fresh encounter starts them empty. (Item/skill buffs will land here too.)
@export var player_buffs: StarshipStats
@export var opponent_buffs: StarshipStats
## Cells currently disabled on each combatant's module grid, mapping a cell [Vector2i] to the turns of
## disable it has left (granted by Disruptor; see [method disable_cell]). A disabled cell deactivates the
## module covering it, so that module stops counting toward the ship's stat profile until it re-enables.
## Counted down one per turn by [method advance_turn].
@export var player_disabled_cells: Dictionary[Vector2i, int] = {}
@export var opponent_disabled_cells: Dictionary[Vector2i, int] = {}

## Each combatant's warp capacity — the bars their side of the meter holds before they can Jump (see
## [method can_jump]) to win outright. Granted by warp-core modules, so it's a copy of the ship's
## [member StarshipStats.warp_capacity]; the match seeds these at setup. Zero means that ship can't warp at all —
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
## The combatant who Jumped (filled their warp and cashed it in), or -1 if none. Decides a warp victory.
@export var warp_winner: int = -1

func _init() -> void:
	# Pure-data defaults only — the combatant ships are built by the [Encounter] node, never fabricated here;
	# each carries its own resource tally (see [EncounterStarshipState]).
	# Fresh per instance so the two combatants never share one buff block (exported Resource defaults can).
	if player_buffs == null:
		player_buffs = StarshipStats.new()
	if opponent_buffs == null:
		opponent_buffs = StarshipStats.new()

## The combatant whose turn it currently is.
func active_combatant() -> Combatant:
	return Combatant.PLAYER if turn_in_round == 1 else Combatant.OPPONENT

## The combatant opposing [param combatant] — the target a mover's damage tiles hit.
func opponent_of(combatant: Combatant) -> Combatant:
	return Combatant.OPPONENT if combatant == Combatant.PLAYER else Combatant.PLAYER

## The ship [param combatant] is fighting in — the owner of its health, stats, module grid, and banked
## resources (the encounter-scoped [EncounterStarshipState]).
func ship_of(combatant: Combatant) -> EncounterStarshipState:
	return player if combatant == Combatant.PLAYER else opponent

## [param combatant]'s current health — its ship's current hull (0 if it has no ship).
func health_of(combatant: Combatant) -> int:
	var ship: StarshipState = ship_of(combatant)
	return ship.health if ship != null else 0

## [param combatant]'s max health — its ship's derived hull, the bar's cap (0 if it has no ship).
func max_health_of(combatant: Combatant) -> int:
	var ship: StarshipState = ship_of(combatant)
	return ship.max_health() if ship != null else 0

## Sets [param combatant]'s current health on its ship, floored at zero. The hull is the source of truth.
func _set_health(combatant: Combatant, value: int) -> void:
	var ship: StarshipState = ship_of(combatant)
	if ship != null:
		ship.health = maxi(0, value)

## [param combatant]'s current shield.
func shield_of(combatant: Combatant) -> int:
	return player_shield if combatant == Combatant.PLAYER else opponent_shield

## Grants [param combatant] [param amount] more shield (the Shields ability).
func add_shield(combatant: Combatant, amount: int) -> void:
	if amount <= 0:
		return
	_set_shield(combatant, shield_of(combatant) + amount)

## Whether [param combatant] is set to dodge the next attack against them.
func dodge_of(combatant: Combatant) -> bool:
	return player_dodge if combatant == Combatant.PLAYER else opponent_dodge

## Arms or clears [param combatant]'s dodge (Evasive Maneuvers arms it; the next attack consumes it).
func set_dodge(combatant: Combatant, on: bool) -> void:
	if combatant == Combatant.PLAYER:
		player_dodge = on
	else:
		opponent_dodge = on

## [param combatant]'s temporary stat layer (the buffs/debuffs stacked on its permanent profile).
func buffs_of(combatant: Combatant) -> StarshipStats:
	return player_buffs if combatant == Combatant.PLAYER else opponent_buffs

## Raises [param combatant]'s temporary [param stat] by [param amount] (negative debuffs it). Target Lock
## raises DAMAGE this way; it stacks for the encounter.
func add_buff(combatant: Combatant, stat: Stat.Type, amount: int) -> void:
	buffs_of(combatant).add_value(stat, amount)

## [param combatant]'s effective stats: its permanent module-grid profile ([param base], supplied by the
## host since the starship owns the grid) with this encounter's temporary buff layer stacked on top. The
## stats combat consumes — the damage stat bonuses the hit, the four colored stats the resource they bank.
func effective_stats(combatant: Combatant, base: StarshipStats) -> StarshipStats:
	var total := StarshipStats.new()
	total.add(base)
	total.add(buffs_of(combatant))
	return total

## The cells currently disabled on [param combatant]'s grid — each deactivates the module covering it.
func disabled_cells_of(combatant: Combatant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _disabled_map(combatant):
		result.append(cell)
	return result

## Disables [param cell] on [param combatant]'s grid for [param turns] turns — the module covering it stops
## counting until the disable expires. Refreshes to the longer remaining if the cell is already disabled.
## Counted down one per turn by [method advance_turn], so a value of N keeps the cell disabled through the
## next N turn changes. A non-positive duration is a no-op (the Disruptor ability).
func disable_cell(combatant: Combatant, cell: Vector2i, turns: int) -> void:
	if turns <= 0:
		return
	var map: Dictionary[Vector2i, int] = _disabled_map(combatant)
	var current: int = map[cell] if map.has(cell) else 0
	map[cell] = maxi(current, turns)

func _disabled_map(combatant: Combatant) -> Dictionary[Vector2i, int]:
	return player_disabled_cells if combatant == Combatant.PLAYER else opponent_disabled_cells

# Counts every disabled cell down one turn and re-enables those that reach zero. Run once per turn change.
func _tick_disabled_cells() -> void:
	for combatant: Combatant in [Combatant.PLAYER, Combatant.OPPONENT]:
		var map: Dictionary[Vector2i, int] = _disabled_map(combatant)
		for cell: Vector2i in map.keys():
			map[cell] -= 1
			if map[cell] <= 0:
				map.erase(cell)

## Applies [param amount] of incoming damage to [param target]: a dodge negates it whole (and is spent), then
## shield absorbs before health. Returns the damage that reached health, or [code]-1[/code] if it was dodged.
## A non-positive amount is a no-op (returns 0).
func deal_damage(target: Combatant, amount: int) -> int:
	if amount <= 0:
		return 0
	if dodge_of(target):
		set_dodge(target, false)
		return -1
	var shield: int = shield_of(target)
	var absorbed: int = mini(shield, amount)
	if absorbed > 0:
		_set_shield(target, shield - absorbed)
	var to_health: int = amount - absorbed
	if to_health > 0:
		_set_health(target, health_of(target) - to_health)
	return to_health

func _set_shield(combatant: Combatant, value: int) -> void:
	if combatant == Combatant.PLAYER:
		player_shield = maxi(0, value)
	else:
		opponent_shield = maxi(0, value)

## Whether the encounter has been decided — a combatant Jumped, or one is out of health.
func is_over() -> bool:
	return warp_winner != -1 or player_health <= 0 or opponent_health <= 0

## The combatant who lost. Only meaningful once [method is_over] is true: the one who didn't Jump if there
## was a warp victory, else the one out of health.
func defeated() -> Combatant:
	if warp_winner != -1:
		return opponent_of(warp_winner)
	return Combatant.PLAYER if player_health <= 0 else Combatant.OPPONENT

## [param combatant]'s filled warp bars — the side of the shared meter in their favor (0 if they're behind).
func warp_of(combatant: Combatant) -> int:
	return maxi(0, warp) if combatant == Combatant.PLAYER else maxi(0, -warp)

## [param combatant]'s warp capacity — the bars their side holds before they can Jump.
func warp_max_of(combatant: Combatant) -> int:
	return player_warp_max if combatant == Combatant.PLAYER else opponent_warp_max

## Adds [param bars] of warp for [param combatant]: the player's pushes the meter up, the opponent's down.
## Clamps to each side's own capacity; without a tug (Campaign) it never drops below zero, so the opponent's
## warp only cancels the player's progress.
func add_warp(combatant: Combatant, bars: int) -> void:
	if bars <= 0:
		return
	warp += bars if combatant == Combatant.PLAYER else -bars
	var low: int = -opponent_warp_max if warp_tug else 0
	warp = clampi(warp, low, player_warp_max)

## Whether [param combatant] has filled their warp and may Jump. The player can at a full meter; the opponent
## only in a tug (Quick Match).
func can_jump(combatant: Combatant) -> bool:
	if combatant == Combatant.PLAYER:
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
