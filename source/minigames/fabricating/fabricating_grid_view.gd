class_name FabricatingGridView
extends Node2D
## Draws a [FabricatingBoard]: the build grid, the packed component footprints, and a placement preview.
## Drawn from the local origin so a [BoardCanvas] frames, centers, and scales it.

const _CELL := Color(0.20, 0.24, 0.34)
const _CELL_BORDER := Color(0.30, 0.35, 0.47)
const _VALID_PREVIEW := Color(0.45, 0.85, 0.45, 0.45)
const _INVALID_PREVIEW := Color(0.9, 0.35, 0.3, 0.45)
const _CELL_INSET := 1.0

var cell_size: float = 96.0
var board: FabricatingBoard

var _preview_cells: Array[Vector2i] = []
var _preview_valid := false

func configure(fabricating_board: FabricatingBoard, cell_size_px: float) -> void:
	board = fabricating_board
	cell_size = cell_size_px
	if not board.changed.is_connected(queue_redraw):
		board.changed.connect(queue_redraw)
	queue_redraw()

## Unscaled pixel size of the grid, for [method BoardCanvas.set_board].
func content_size() -> Vector2:
	return Vector2(board.columns * cell_size, board.rows * cell_size) if board != null else Vector2.ZERO

## Grid cell under [param global_position] (a [BoardCanvas]-forwarded global point), or (-1, -1) outside.
func cell_at(global_position: Vector2) -> Vector2i:
	if board == null:
		return Vector2i(-1, -1)
	var local := to_local(global_position)
	var cell := Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))
	if not board.cell_exists(cell):
		return Vector2i(-1, -1)
	return cell

func set_preview(cells: Array[Vector2i], valid: bool) -> void:
	_preview_cells = cells
	_preview_valid = valid
	queue_redraw()

func clear_preview() -> void:
	_preview_cells = []
	queue_redraw()

func _draw() -> void:
	if board == null:
		return
	for y in board.rows:
		for x in board.columns:
			var rect := _cell_rect(Vector2i(x, y))
			draw_rect(rect, _CELL)
			draw_rect(rect, _CELL_BORDER, false, 1.0)
	for index in board.placements.size():
		var footprint: Array[Vector2i] = board.footprints[index]
		_draw_piece(board.pieces[index], footprint, board.placements[index])
	for cell: Vector2i in _preview_cells:
		draw_rect(_cell_rect(cell), _VALID_PREVIEW if _preview_valid else _INVALID_PREVIEW)

func _draw_piece(piece: ItemBlueprint, footprint: Array[Vector2i], placement: StackPlacement) -> void:
	var fill: Color = piece.color
	fill.a = 1.0
	for cell: Vector2i in GridGeometry.occupied_cells(footprint, placement.anchor, placement.rotation_steps):
		var rect := _cell_rect(cell)
		draw_rect(rect, fill)
		draw_rect(rect, piece.color.lightened(0.4), false, 2.0)

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell.x * cell_size + _CELL_INSET, cell.y * cell_size + _CELL_INSET),
		Vector2(cell_size - _CELL_INSET * 2.0, cell_size - _CELL_INSET * 2.0))
