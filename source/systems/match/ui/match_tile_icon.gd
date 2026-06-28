class_name MatchTileIcon
extends Control
## A single match-tile glyph drawn at the control's size, for UI readouts (the stat strip beneath a
## portrait). Wraps a [MatchTile] and scales it to fit — the board's art, shrunk.

@export var kind: int = 0:
	set(value):
		kind = value
		if _tile != null:
			_tile.kind = value

var _tile: MatchTile

func _ready() -> void:
	_tile = MatchTile.new()
	add_child(_tile)
	_tile.kind = kind
	_fit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()

# The tile draws centred on its origin spanning 0.8 unit-cells; scale that span to the control's shorter
# side (leaving a hair of margin) and centre it.
func _fit() -> void:
	if _tile == null:
		return
	var side: float = minf(size.x, size.y)
	_tile.scale = Vector2(side, side)
	_tile.position = size * 0.5
