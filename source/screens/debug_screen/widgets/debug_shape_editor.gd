@tool
class_name DebugShapeEditor
extends Control
## A simple 4×4 footprint editor: tap a cell to toggle whether it's part of the shape. Custom-drawn (filled
## cells in the module's accent, empty cells outlined) so it reads clearly and works the same on touch and
## desktop. [code]@tool[/code] so the empty grid renders in the editor. On every change it hands back the
## active cells as offsets; the caller turns them into a [PieceShape]. Local cell state is the source of
## truth while open, so toggling never makes the grid jump.

const GRID := 4
const _CELL := 104.0
const _GAP := 8.0
const _FILL_EMPTY := Color(0.16, 0.17, 0.21)
const _BORDER := Color(0.65, 0.70, 0.80, 0.35)

var _active: Array[bool] = []
var _accent: Color = Color.WHITE
# func(offsets: Array[Vector2i]) -> void — receives the active cells whenever the shape changes.
var _on_changed: Callable

## Builds an editor seeded with [param offsets], cells filled in [param accent]; [param on_changed] fires
## with the active cells on every tap.
static func create(offsets: Array[Vector2i], accent: Color, on_changed: Callable) -> DebugShapeEditor:
	var editor := DebugShapeEditor.new()
	editor._accent = accent if accent.a > 0.0 else Color.WHITE
	editor._on_changed = on_changed
	editor._active.resize(GRID * GRID)
	for cell: Vector2i in offsets:
		if cell.x >= 0 and cell.x < GRID and cell.y >= 0 and cell.y < GRID:
			editor._active[cell.y * GRID + cell.x] = true
	return editor

func _ready() -> void:
	var side := GRID * _CELL
	custom_minimum_size = Vector2(side, side)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# In the editor the cell state is never seeded by create(); fill it so the empty grid draws.
	if _active.is_empty():
		_active.resize(GRID * GRID)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var position := Vector2.INF
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			position = button.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			position = touch.position
	if position == Vector2.INF:
		return

	var cx := int(position.x / _CELL)
	var cy := int(position.y / _CELL)
	if cx < 0 or cx >= GRID or cy < 0 or cy >= GRID:
		return
	var index := cy * GRID + cx
	_active[index] = not _active[index]
	queue_redraw()
	_emit()

func _draw() -> void:
	if _active.is_empty():
		_active.resize(GRID * GRID)
	for y: int in GRID:
		for x: int in GRID:
			var rectangle := Rect2(x * _CELL + _GAP, y * _CELL + _GAP, _CELL - 2.0 * _GAP, _CELL - 2.0 * _GAP)
			if _active[y * GRID + x]:
				draw_rect(rectangle, _accent)
			else:
				draw_rect(rectangle, _FILL_EMPTY)
				draw_rect(rectangle, _BORDER, false, 1.0)

func _emit() -> void:
	if Engine.is_editor_hint() or not _on_changed.is_valid():
		return
	var offsets: Array[Vector2i] = []
	for y: int in GRID:
		for x: int in GRID:
			if _active[y * GRID + x]:
				offsets.append(Vector2i(x, y))
	_on_changed.call(offsets)
