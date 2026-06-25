class_name ModuleGridView
extends Node2D
## Draws a [ModuleGrid]: the bay's existing cells as a framed grid (missing cells leave gaps,
## carving the hull silhouette), the packed modules as cohesive named footprints (one shape per
## module, not a grid of cells), and a destination preview. Drawn from the local origin so a
## [BoardCanvas] frames, centers, and scales it.

const _BACKDROP := Color(0.16, 0.21, 0.34)
const _CELL := Color(0.27, 0.33, 0.51)
const _CELL_BORDER := Color(0.35, 0.41, 0.57)
const _VALID_PREVIEW := Color(0.45, 0.85, 0.45, 0.45)
const _INVALID_PREVIEW := Color(0.9, 0.35, 0.3, 0.45)
const _FOCUS_OUTLINE := Color(1, 1, 1, 0.95)
const _FOCUS_WIDTH := 4.0
const _CELL_INSET := 1.0

# A module is drawn as one cohesive shape, not a grid of cells: its cells fill seamlessly (no internal
# seams) inset by [_MODULE_GAP] from the bay grid, with a single outline traced around the footprint's
# outer perimeter. The module's name is lettered across the footprint.
const _MODULE_GAP := 3.0
const _MODULE_BORDER_WIDTH := 2.0
const _NAME_COLOR := Color(1, 1, 1, 0.95)
const _NAME_OUTLINE := Color(0, 0, 0, 0.55)
const _NAME_OUTLINE_SIZE := 4
const _NAME_PADDING := 4.0

var cell_size: float = 96.0
var grid: ModuleGrid

var _preview_cells: Array[Vector2i] = []
var _preview_valid := false
var _focus_cells: Array[Vector2i] = []

func configure(module_grid: ModuleGrid, cell_size_px: float) -> void:
	grid = module_grid
	cell_size = cell_size_px
	if not grid.changed.is_connected(queue_redraw):
		grid.changed.connect(queue_redraw)
	queue_redraw()

## Unscaled pixel size of the bounding grid, for [method BoardCanvas.set_board].
func content_size() -> Vector2:
	return Vector2(grid.columns * cell_size, grid.rows * cell_size) if grid != null else Vector2.ZERO

## Bay cell under [param global_position] (a [BoardCanvas]-forwarded global point), or (-1, -1)
## outside the bounding grid. Holes return their coordinate too; callers gate on [ModuleGrid].
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

## Highlights [param cells] with a bright outline — the footprint of the focused (tapped) module, so
## the player can see which module they're inspecting.
func set_focus(cells: Array[Vector2i]) -> void:
	_focus_cells = cells
	queue_redraw()

func clear_focus() -> void:
	_focus_cells = []
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
	if not _focus_cells.is_empty():
		_draw_footprint_outline(_focus_cells, _FOCUS_OUTLINE, _FOCUS_WIDTH)
	for cell: Vector2i in _preview_cells:
		draw_rect(_cell_rect(cell), _VALID_PREVIEW if _preview_valid else _INVALID_PREVIEW)

# A module as one cohesive piece: its cells filled seamlessly (internal seams meet at full cell extent),
# a single outline around the whole footprint, and its name lettered across it.
func _draw_module(placed: PlacedModule) -> void:
	var cells := placed.cells
	var fill: Color = placed.module.color
	fill.a = 1.0
	for cell: Vector2i in cells:
		draw_rect(_module_cell_rect(cell, cells), fill)
	_draw_footprint_outline(cells, placed.module.color.lightened(0.4), _MODULE_BORDER_WIDTH)
	_draw_module_name(placed)

# A cell's fill rect within its module: pulled in by [_MODULE_GAP] on sides that face outside the
# footprint, but flush to the cell edge on sides shared with another cell of the same module — so
# neighbouring cells of one module tile seamlessly while the module as a whole sits gapped off the grid.
func _module_cell_rect(cell: Vector2i, cells: Array[Vector2i]) -> Rect2:
	var x := cell.x * cell_size
	var y := cell.y * cell_size
	var left := x + (0.0 if cells.has(cell + Vector2i.LEFT) else _MODULE_GAP)
	var top := y + (0.0 if cells.has(cell + Vector2i.UP) else _MODULE_GAP)
	var right := x + cell_size - (0.0 if cells.has(cell + Vector2i.RIGHT) else _MODULE_GAP)
	var bottom := y + cell_size - (0.0 if cells.has(cell + Vector2i.DOWN) else _MODULE_GAP)
	return Rect2(left, top, right - left, bottom - top)

# Traces [color] around the outer perimeter of [cells]: for each cell, an edge is drawn only on sides
# that border outside the footprint, so a multi-cell module gets one outline, not a box per cell.
func _draw_footprint_outline(cells: Array[Vector2i], color: Color, width: float) -> void:
	for cell: Vector2i in cells:
		var rect := _module_cell_rect(cell, cells)
		var top_left := rect.position
		var top_right := rect.position + Vector2(rect.size.x, 0.0)
		var bottom_left := rect.position + Vector2(0.0, rect.size.y)
		var bottom_right := rect.position + rect.size
		if not cells.has(cell + Vector2i.UP):
			draw_line(top_left, top_right, color, width)
		if not cells.has(cell + Vector2i.DOWN):
			draw_line(bottom_left, bottom_right, color, width)
		if not cells.has(cell + Vector2i.LEFT):
			draw_line(top_left, bottom_left, color, width)
		if not cells.has(cell + Vector2i.RIGHT):
			draw_line(top_right, bottom_right, color, width)

# Letters the module's name across its footprint, centred and wrapped to the footprint width, with a
# dark outline so it stays legible over any module colour.
func _draw_module_name(placed: PlacedModule) -> void:
	if placed.module == null or placed.module.name.is_empty():
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var bounds := _footprint_bounds(placed.cells)
	var font_size := maxi(12, roundi(cell_size * 0.2))
	var wrap_width := bounds.size.x - (_MODULE_GAP + _NAME_PADDING) * 2.0
	var text := placed.module.name
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, wrap_width, font_size)
	var origin_x := bounds.position.x + _MODULE_GAP + _NAME_PADDING
	var baseline_y := bounds.position.y + (bounds.size.y - text_size.y) * 0.5 + font.get_ascent(font_size)
	var pos := Vector2(origin_x, baseline_y)
	draw_multiline_string_outline(
		font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, wrap_width, font_size, -1, _NAME_OUTLINE_SIZE, _NAME_OUTLINE)
	draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, wrap_width, font_size, -1, _NAME_COLOR)

# The pixel bounding box of [cells] — for laying the name out across the whole footprint.
func _footprint_bounds(cells: Array[Vector2i]) -> Rect2:
	var min_cell := cells[0]
	var max_cell := cells[0]
	for cell: Vector2i in cells:
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	var origin := Vector2(min_cell.x * cell_size, min_cell.y * cell_size)
	var span := Vector2((max_cell.x - min_cell.x + 1) * cell_size, (max_cell.y - min_cell.y + 1) * cell_size)
	return Rect2(origin, span)

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell.x * cell_size + _CELL_INSET, cell.y * cell_size + _CELL_INSET),
		Vector2(cell_size - _CELL_INSET * 2.0, cell_size - _CELL_INSET * 2.0))
