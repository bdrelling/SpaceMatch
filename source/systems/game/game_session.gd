extends Node
## The running game — the `GameSession` autoload. Globally reachable so any screen reads the current game
## without being handed it. Holds the [member game_state] today; the session grows to own more than its state
## over time (the tick clock, run/match config, save slot), which is why the state is a named field, not the
## session itself. The entity nodes that represent the state ([Starship], [Encounter]) are owned by the hosts
## that show them ([Game]), not by the session; the wallet is plain state with no node.

## The persisted state of the running game — the player starship, wallet, and active encounter. The save reads
## this; hosts build the entity nodes that represent it. Replaced wholesale by [method start_new_game].
var game_state: GameState

func _ready() -> void:
	# Boot with a fresh game so a directly-launched screen always has state to read; hosts re-start it on a
	# clean entry. Tests call [method start_new_game] to reset between runs.
	if game_state == null:
		start_new_game()

## Resets to a fresh single-player game. The session holds no content defaults, so it hands the seed off to
## [GameCoordinator], which builds the default starship and empty wallet and assigns the fresh state here.
func start_new_game() -> void:
	GameCoordinator.start_new_game()
