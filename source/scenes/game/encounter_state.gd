class_name EncounterState
extends Resource
## The active encounter's slice of the game state — state only the encounter (the match-3 play
## screen) has, which the 3D game never reads. Null on [GameState] when no encounter is running.
## Lives under [member GameState.encounter], serialized with the one save.
##
## Holds the opponent's ship (the player's lives on [GameState]), each combatant's encounter health, and
## the turn/round counter that the match minigame advances after each move and shows in its top row.

## The two combatants. Turn 1 of a round is the player's, turn 2 the opponent's.
enum Combatant { PLAYER, OPPONENT }

## A round is one turn per combatant.
const TURNS_PER_ROUND: int = 2

## Both combatants start an encounter at this much health.
const _STARTING_HEALTH: int = 100

## The opponent starts with a copy of the default ship for now — its own ship, but not yet a distinct
## one. A real roster lands with AI control later.
const _DEFAULT_OPPONENT := preload("res://resources/starships/default_starship_blueprint.tres")

## The opponent's ship. Encounter-scoped — only exists while an encounter runs. Human-controlled for
## now; AI lands later.
@export var opponent: StarshipState

## 1-based round counter.
@export var round_number: int = 1
## Which turn within the current round, 1..[constant TURNS_PER_ROUND].
@export var turn_in_round: int = 1

## The shared health cap and each combatant's current health — depleted by matched damage tiles (see
## [method deal_damage]) and shown on the portrait health bars.
@export var max_health: int = _STARTING_HEALTH
@export var player_health: int = _STARTING_HEALTH
@export var opponent_health: int = _STARTING_HEALTH

func _init() -> void:
	if opponent == null:
		opponent = StarshipGenerator.generate(_DEFAULT_OPPONENT)

## The combatant whose turn it currently is.
func active_combatant() -> Combatant:
	return Combatant.PLAYER if turn_in_round == 1 else Combatant.OPPONENT

## The combatant opposing [param combatant] — the target a mover's damage tiles hit.
func opponent_of(combatant: Combatant) -> Combatant:
	return Combatant.OPPONENT if combatant == Combatant.PLAYER else Combatant.PLAYER

## [param combatant]'s current health.
func health_of(combatant: Combatant) -> int:
	return player_health if combatant == Combatant.PLAYER else opponent_health

## Reduces [param target]'s health by [param amount] (clamped to zero). A non-positive amount is a no-op.
func deal_damage(target: Combatant, amount: int) -> void:
	if amount <= 0:
		return
	if target == Combatant.PLAYER:
		player_health = maxi(0, player_health - amount)
	else:
		opponent_health = maxi(0, opponent_health - amount)

## Ends the active combatant's turn: advances to the next turn, rolling into the next round once both
## combatants have moved.
func advance_turn() -> void:
	turn_in_round += 1
	if turn_in_round > TURNS_PER_ROUND:
		turn_in_round = 1
		round_number += 1
