class_name ArcadeState
extends Resource
## The arcade's own slice of the game state — state that only the arcade has and the 3D game never
## reads (it has no concept of these minigames). Holds the salvaging field; grows as the arcade gains
## more arcade-only state. Lives under [member GameState.arcade], serialized with the one save.

@export var salvaging: SalvagingState
