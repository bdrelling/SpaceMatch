class_name DisabledCells
extends Resource
## The cells currently disabled on each combatant's module grid — keyed by side ([code]is_player[/code]) rather
## than by [Combatant] so it stays a pure value object. Each entry maps a cell [Vector2i] to the turns of disable
## it has left (granted by Disruptor; see [method disable]). A disabled cell deactivates the module covering it,
## so that module stops counting toward the starship's stat profile until it re-enables. Held by [EncounterState],
## counted down one per turn by [method advance].

@export var player_cells: Dictionary[Vector2i, int] = {}
@export var opponent_cells: Dictionary[Vector2i, int] = {}


## Disables [param cell] on [param is_player]'s grid for [param turns] turns. Refreshes to the longer remaining
## if the cell is already disabled. A non-positive duration is a no-op.
func disable(is_player: bool, cell: Vector2i, turns: int) -> void:
	if turns <= 0:
		return
	var map: Dictionary[Vector2i, int] = _map(is_player)
	var current: int = map[cell] if map.has(cell) else 0
	map[cell] = maxi(current, turns)


## The cells currently disabled on [param is_player]'s grid — each deactivates the module covering it.
func cells_of(is_player: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _map(is_player):
		result.append(cell)
	return result


## Counts every disabled cell down one turn and re-enables those that reach zero. Run once per turn change.
func advance() -> void:
	for map: Dictionary[Vector2i, int] in [player_cells, opponent_cells]:
		for cell: Vector2i in map.keys():
			map[cell] -= 1
			if map[cell] <= 0:
				map.erase(cell)


func _map(is_player: bool) -> Dictionary[Vector2i, int]:
	return player_cells if is_player else opponent_cells
