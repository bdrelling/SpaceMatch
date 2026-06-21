class_name ItemFootprintIcon
extends Control
## Draws an [ItemBlueprint]'s grid footprint as filled cells in the item's colour, scaled to fit this
## control. The small at-a-glance "module shape" shown wherever an item is presented by picture rather
## than text — the outfitting strip or a fabricating recipe. Display only; never
## intercepts pointer input.

## The item to draw. Null draws nothing.
var blueprint: ItemBlueprint:
	set(value):
		blueprint = value
		queue_redraw()

## Clear space (px) kept inside each edge, so the footprint never touches the border.
@export var inset: float = 4.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if blueprint == null:
		return
	var cells: Array[Vector2i] = blueprint.footprint_cells
	if cells.is_empty():
		return
	var span := Vector2i.ONE
	for cell: Vector2i in cells:
		span.x = maxi(span.x, cell.x + 1)
		span.y = maxi(span.y, cell.y + 1)
	var inner := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	var cell_size: float = minf(inner.size.x / span.x, inner.size.y / span.y)
	var origin := inner.position + (inner.size - Vector2(span) * cell_size) * 0.5
	var fill: Color = blueprint.color
	fill.a = 1.0
	var border: Color = blueprint.color.lightened(0.4)
	for cell: Vector2i in cells:
		var rect := Rect2(origin + Vector2(cell) * cell_size, Vector2(cell_size, cell_size) - Vector2.ONE * 2.0)
		draw_rect(rect, fill)
		draw_rect(rect, border, false, 1.0)
