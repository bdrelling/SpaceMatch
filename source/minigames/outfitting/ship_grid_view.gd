class_name ShipGridView
extends Node2D
## Draws a [ShipModuleGrid]: the bay's existing cells as a framed grid (missing cells leave gaps,
## carving the hull silhouette), the packed modules as colored footprints, and a destination
## preview. Drawn from the local origin so a [BoardCanvas] frames, centers, and scales it.

const _BACKDROP := Color(0.16, 0.21, 0.34)
const _CELL := Color(0.27, 0.33, 0.51)
const _CELL_BORDER := Color(0.35, 0.41, 0.57)
const _VALID_PREVIEW := Color(0.45, 0.85, 0.45, 0.45)
const _INVALID_PREVIEW := Color(0.9, 0.35, 0.3, 0.45)
const _CELL_INSET := 1.0

var cell_size: float = 96.0
var grid: ShipModuleGrid

var _preview_cells: Array[Vector2i] = []
var _preview_valid := false

func configure(module_grid: ShipModuleGrid, cell_size_px: float) -> void:
	grid = module_grid
	cell_size = cell_size_px
	if not grid.changed.is_connected(queue_redraw):
		grid.changed.connect(queue_redraw)
	queue_redraw()

## Unscaled pixel size of the bounding grid, for [method BoardCanvas.set_board].
func content_size() -> Vector2:
	return Vector2(grid.columns * cell_size, grid.rows * cell_size) if grid != null else Vector2.ZERO

## Bay cell under [param global_position] (a [BoardCanvas]-forwarded global point), or (-1, -1)
## outside the bounding grid. Holes return their coordinate too; callers gate on [ShipModuleGrid].
func cell_at(global_position: Vector2) -> Vector2i:
	if grid == null:
		return Vector2i(-1, -1)
	var local := to_local(global_position)
	var cell := Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.columns or cell.y >= grid.rows:
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
	if grid == null:
		return
	for cell: Vector2i in grid.existing_cells():
		var rect := _cell_rect(cell)
		draw_rect(rect, _CELL)
		draw_rect(rect, _CELL_BORDER, false, 1.0)
	for placed: PlacedModule in grid.placed_modules():
		_draw_module(placed)
	for cell: Vector2i in _preview_cells:
		draw_rect(_cell_rect(cell), _VALID_PREVIEW if _preview_valid else _INVALID_PREVIEW)

func _draw_module(placed: PlacedModule) -> void:
	var fill: Color = placed.module.color
	fill.a = 1.0
	for cell: Vector2i in placed.cells:
		var rect := _cell_rect(cell)
		draw_rect(rect, fill)
		draw_rect(rect, placed.module.color.lightened(0.4), false, 2.0)

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell.x * cell_size + _CELL_INSET, cell.y * cell_size + _CELL_INSET),
		Vector2(cell_size - _CELL_INSET * 2.0, cell_size - _CELL_INSET * 2.0))
