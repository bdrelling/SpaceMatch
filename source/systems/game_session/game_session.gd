class_name GameSession
extends RefCounted
## The live runtime of one running game: holds a [GameState] and binds nodes to it. One per running
## game — never an autoload, so tests spin up fresh games.

var state: GameState

func _init(_state: GameState = null) -> void:
	state = _state if _state != null else GameState.new()

## A fresh game — a default ship.
static func new_game() -> GameSession:
	return GameSession.new()
