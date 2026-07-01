class_name WarpMeter
extends Resource
## The encounter's shared warp meter — the signed tug between the two combatants' Jump progress, keyed by side
## ([code]is_player[/code]) rather than by [Combatant] so it stays a pure value object. Positive [member value]
## is the player's progress toward their Jump, negative the opponent's. Matching Warp tiles push the meter toward
## the mover's end ([method add]); filling a side's [member capacity] lets that side Jump ([method can_jump]) to
## win outright ([method jump]). Held by [EncounterState]; encounter-scoped, so it starts empty.

## Signed meter: positive is the player's progress, negative the opponent's.
@export var value: int = 0
## Quick Match runs warp as a two-way tug — the opponent collects toward their own Jump, so the meter can go
## negative and they win at -[member opponent_capacity]. Campaign leaves this false: the opponent's warp only
## drains the player's (floored at zero) and can never win.
@export var tug: bool = false
## Each side's capacity — the bars it holds before it can Jump. Granted by warp-core modules; the match seeds
## these at setup. Zero means that side can't warp at all. The two can differ, which is why they live per side.
@export var player_capacity: int = 0
@export var opponent_capacity: int = 0
## Whether a side has Jumped (filled its capacity and cashed it in) — decides a warp victory.
@export var has_winner: bool = false
## Which side won; only meaningful once [member has_winner] is true.
@export var winner_is_player: bool = false


## [param is_player]'s filled bars — the side of the meter in their favour (0 if they're behind).
func progress_of(is_player: bool) -> int:
	return maxi(0, value) if is_player else maxi(0, -value)


## [param is_player]'s capacity — the bars their side holds before they can Jump.
func capacity_of(is_player: bool) -> int:
	return player_capacity if is_player else opponent_capacity


## Adds [param bars] of warp for [param is_player]: the player's pushes the meter up, the opponent's down.
## Clamps to each side's own capacity; without a tug (Campaign) it never drops below zero, so the opponent's
## warp only cancels the player's progress.
func add(is_player: bool, bars: int) -> void:
	if bars <= 0:
		return
	value += bars if is_player else -bars
	var low: int = -opponent_capacity if tug else 0
	value = clampi(value, low, player_capacity)


## Whether [param is_player] has filled their side and may Jump. The player can at a full meter; the opponent
## only in a tug (Quick Match).
func can_jump(is_player: bool) -> bool:
	if is_player:
		return player_capacity > 0 and value >= player_capacity
	return tug and opponent_capacity > 0 and value <= -opponent_capacity


## [param is_player] Jumps: records the win and expends the meter. A no-op when they can't yet.
func jump(is_player: bool) -> void:
	if not can_jump(is_player):
		return
	has_winner = true
	winner_is_player = is_player
	value = 0
