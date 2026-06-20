class_name GameState
extends Resource
## One running game's runtime state: the [PlayerState] roster and the [OutpostState]. This is what
## a save serializes; a [GameSession] holds it live. Never a project `.tres`.

@export var players: Array[PlayerState] = []
@export var outpost: OutpostState
@export var clock: GameClockState

## The arcade's own slice of state — arcade-only, never read by the 3D game. Null outside the arcade.
@export var arcade: ArcadeState

func _init() -> void:
	if clock == null:
		clock = GameClockState.new()
