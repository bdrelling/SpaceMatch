class_name ModuleGridThumbnail
extends Control
## Low-resolution, read-only sample of a [ModuleGrid]: the hull silhouette plus its packed modules,
## scaled to fit this control. For at-a-glance previews (e.g. an outpost's landing pads); the
## interactive board is [ModuleGridView].

const _CELL := Color(0.27, 0.33, 0.51)
const _CELL_BORDER := Color(0.35, 0.41, 0.57, 0.6)

var grid: ModuleGridState:
	set(value):
		grid = value
		queue_redraw()

func _draw() -> void:
	if grid == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var columns: int = grid.columns
	var rows: int = grid.rows
	if columns <= 0 or rows <= 0:
		return
	var cell_size: float = minf(size.x / columns, size.y / rows)
	var origin := (size - Vector2(columns, rows) * cell_size) * 0.5
	for cell: Vector2i in grid.existing_cells():
		draw_rect(_cell_rect(origin, cell_size, cell), _CELL)
		draw_rect(_cell_rect(origin, cell_size, cell), _CELL_BORDER, false, 1.0)
	for module_state: ModuleState in grid.modules:
		_draw_module(origin, cell_size, module_state, grid.cells_of(module_state))

func _draw_module(origin: Vector2, cell_size: float, module_state: ModuleState, cells: Array[Vector2i]) -> void:
	var fill: Color = module_state.blueprint.color
	fill.a = 1.0
	for cell: Vector2i in cells:
		draw_rect(_cell_rect(origin, cell_size, cell), fill)

func _cell_rect(origin: Vector2, cell_size: float, cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * cell_size + Vector2(0.5, 0.5), Vector2(cell_size - 1.0, cell_size - 1.0))
