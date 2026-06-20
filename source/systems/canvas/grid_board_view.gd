class_name GridBoardView
extends Node2D
## Board backdrop for a [[Grid]]: a dark backing plus a faint per-cell grid,
## drawn from the (0, 0) origin so a [[BoardCanvas]] can frame it. Owns the grid
## and exposes it for tile placement and cell math. The grid stays drawing-free;
## this is the consumer-side background, not part of the grid system.

const _BACKDROP_COLOR := Color(0.16, 0.21, 0.34)
const _CELL_COLOR := Color(1, 1, 1, 0.04)
const _CELL_BORDER_COLOR := Color(1, 1, 1, 0.08)

var grid: Grid

var _columns: int = 0
var _rows: int = 0
var _cell_size: float = 64.0

func _init() -> void:
	grid = Grid.new()
	grid.auto_center = false
	add_child(grid)

## Sizes the view (and its grid) to a [param columns]×[param rows] board of
## [param cell_size]px cells, anchored at the local origin.
func configure(columns: int, rows: int, cell_size: float) -> void:
	_columns = columns
	_rows = rows
	_cell_size = cell_size
	grid.cell_size = cell_size
	grid.columns = columns
	grid.rows = rows
	grid.board_origin = Vector2.ZERO
	queue_redraw()

## Unscaled pixel size of the board, for [method BoardCanvas.set_board].
func content_size() -> Vector2:
	return Vector2(_columns * _cell_size, _rows * _cell_size)

func _draw() -> void:
	if _columns <= 0 or _rows <= 0:
		return
	draw_rect(Rect2(Vector2(-4, -4), content_size() + Vector2(8, 8)), _BACKDROP_COLOR)
	for y: int in _rows:
		for x: int in _columns:
			var rect: Rect2 = grid.cell_rect(Vector2i(x, y))
			draw_rect(rect, _CELL_COLOR)
			draw_rect(rect, _CELL_BORDER_COLOR, false, 1.0)
