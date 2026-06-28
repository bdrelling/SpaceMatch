extends Node
## The running game — the `GameSession` autoload. Globally reachable so any screen reads the current game
## without being handed it. Holds the [member game_state] today; the session grows to own more than its state
## over time (the tick clock, run/match config, save slot), which is why the state is a named field, not the
## session itself. The entity nodes that represent the state ([Starship], [Wallet], [Encounter]) are owned by
## the hosts that show them ([Game]), not by the session.

## The default starship a fresh game starts with.
const _DEFAULT_STARSHIP := preload("res://resources/starships/default_starship_blueprint.tres")

## The persisted state of the running game — the player starship, wallet, and active encounter. The save reads
## this; hosts build the entity nodes that represent it. Replaced wholesale by [method start_new_game].
var game_state: GameState

func _ready() -> void:
	# Boot with a fresh game so a directly-launched screen always has state to read; hosts re-start it on a
	# clean entry. Tests call [method start_new_game] to reset between runs.
	if game_state == null:
		start_new_game()

## Resets to a fresh single-player game: a default player starship and an empty wallet, no encounter yet (a host
## opens one). The starship's state is built through the [Starship] node factory — the builder node is transient
## (freed here); the host that shows the starship wraps this state in a node it owns.
func start_new_game() -> void:
	game_state = GameState.new()
	var starship := Starship.create(_DEFAULT_STARSHIP)
	if starship != null:
		game_state.starship = starship.state
		starship.free()
	game_state.wallet = WalletState.new()
