class_name GameCoordinator
extends RefCounted
## The seam between content and the running session: it builds the game's states through the existing entity
## factories and points [code]GameSession[/code] at them. All-static and stateless — it owns the default
## player and opponent blueprints (the only content defaults the game ships with) but no game logic and no
## state of its own. The [Encounter] node it returns is owned by the host that shows it, never by the session.

## The player's default fight starship — what a fresh game seeds, and the Quick Match player when no session
## starship exists yet.
const _DEFAULT_STARSHIP := preload("res://data/starships/default_starship_blueprint.tres")
## The computer's default starship — distinct from the player's (no warp core, so the AI can't Jump).
const _DEFAULT_COMPUTER_STARSHIP := preload("res://data/starships/computer_default_starship_blueprint.tres")

## Builds an [Encounter] from two ready combatant states and points the session at its state, returning the
## node for the host to mount and free. The player's state must already be a clone of the persistent starship
## (see [method start_quick_match]) so combat never mutates the save.
static func start_encounter(player_state: StarshipState, opponent_state: StarshipState) -> Encounter:
	var encounter := Encounter.create(player_state, opponent_state)
	if GameSession.game_state != null:
		GameSession.game_state.encounter = encounter.state
	return encounter

## Opens a Quick Match: the player is a fresh clone of the running starship (the default player when no game
## seeds one), the opponent the computer default. Builds the encounter, points the session at it, and returns
## the node the host owns.
static func start_quick_match() -> Encounter:
	return start_encounter(_player_state(), _starship_state(_DEFAULT_COMPUTER_STARSHIP))

## Seeds a fresh single-player game onto the session: a default player starship and an empty wallet, no
## encounter yet (a host opens one). Replaces [member GameSession.game_state] wholesale.
static func start_new_game() -> void:
	var game_state := GameState.new()
	game_state.starship = _starship_state(_DEFAULT_STARSHIP)
	game_state.wallet = WalletState.new()
	GameSession.game_state = game_state

# The Quick Match player's state: a clone of the running starship so the fight can't touch the save, or a
# fresh default when no game (or no starship) backs the session.
static func _player_state() -> StarshipState:
	if GameSession.game_state != null and GameSession.game_state.starship != null:
		return GameSession.game_state.starship.clone()
	return _starship_state(_DEFAULT_STARSHIP)

# Builds a [StarshipState] from a blueprint through the transient [Starship] node factory — the builder node
# is freed here; the state outlives it (the same pattern the session seed used).
static func _starship_state(blueprint: StarshipBlueprint) -> StarshipState:
	var starship := Starship.create(blueprint)
	var state: StarshipState = starship.state
	starship.free()
	return state
