class_name MatchTileState
extends GridObjectState
## Single-cell match tile. `kind` doubles into `state["kind"]`, which is what [[MatchCondition]]'s default
## resolver matches on; `owner` doubles into `state["owner"]` so a board scan can read tile ownership generically.

#region Properties

var kind: int
## Which combatant owns this tile on a shared board — its [member Entity.id] (0 player, 1 opponent), or -1
## for neutral. Doubles into `state["owner"]` so a board scan (e.g. a future occupation-scoring rule) can
## read it generically.
var owner: int

#endregion

#region Methods


func _init(occupied_cells: Array[Vector2i] = [], tile_kind: int = 0, tile_owner: int = -1) -> void:
	super(occupied_cells)
	kind = tile_kind
	owner = tile_owner
	state["kind"] = tile_kind
	state["owner"] = tile_owner

#endregion
