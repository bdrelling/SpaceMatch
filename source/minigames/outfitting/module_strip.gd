class_name ModuleStrip
extends Control
## Horizontal strip of packable modules, each drawn as its grid footprint rather than text. A tap picks
## one up ([signal module_pressed]); a horizontal drag scrolls the row, so on touch a tap and a scroll
## never fight (the press is classified by travel, like the board's gesture recognizer). The held
## module's slot stays lit. Presentation only — the host owns the modules.

signal module_pressed(stack: ItemStack)

const _SLOT_SIZE := Vector2(120.0, 108.0)
const _SLOT_SPACING := 12.0
const _EDGE_PADDING := 14.0
## A press that travels past this many pixels reads as a scroll, not a tap.
const _TAP_SLOP := 12.0
## Fraction of the slot the footprint fills, leaving room for the quantity badge.
const _SHAPE_INSET := 18.0
const _QUANTITY_FONT_SIZE := 22

const _SLOT_BACKGROUND := Color(0.16, 0.21, 0.34)
const _SLOT_BORDER := Color(1, 1, 1, 0.12)
const _SELECTED_BORDER := Color(0.95, 0.78, 0.3)

var _stacks: Array[ItemStack] = []
var _selected: ItemStack

var _scroll: float = 0.0
var _pressed: bool = false
var _press_position := Vector2.ZERO
var _press_scroll: float = 0.0
var _scrolling: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size.y = _SLOT_SIZE.y + _EDGE_PADDING * 2.0
	resized.connect(_clamp_scroll)

## Replaces the row; preserves the scroll offset, clamped to the new content width.
func set_modules(stacks: Array[ItemStack]) -> void:
	_stacks = stacks
	_clamp_scroll()
	queue_redraw()

## Lights the slot whose stack matches (the held module); pass null to clear.
func set_selected(stack: ItemStack) -> void:
	_selected = stack
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.index != 0:
			return
		if touch.pressed:
			_begin_press(touch.position)
		else:
			_end_press(touch.position)
		accept_event()
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		if drag.index == 0:
			_update_press(drag.position)
			accept_event()
		return
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_begin_press(button.position)
		else:
			_end_press(button.position)
		accept_event()
		return
	if event is InputEventMouseMotion and _pressed:
		_update_press((event as InputEventMouseMotion).position)
		accept_event()

func _begin_press(local_position: Vector2) -> void:
	_pressed = true
	_press_position = local_position
	_press_scroll = _scroll
	_scrolling = false

func _update_press(local_position: Vector2) -> void:
	if not _pressed:
		return
	var travel: float = local_position.x - _press_position.x
	if absf(travel) > _TAP_SLOP:
		_scrolling = true
	if _scrolling:
		_scroll = _press_scroll - travel
		_clamp_scroll()
		queue_redraw()

func _end_press(local_position: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	if _scrolling:
		return
	var stack := _stack_at(local_position)
	if stack != null:
		module_pressed.emit(stack)

# Stack whose slot contains [param local_position], or null.
func _stack_at(local_position: Vector2) -> ItemStack:
	for index: int in _stacks.size():
		if _slot_rect(index).has_point(local_position):
			return _stacks[index]
	return null

func _slot_rect(index: int) -> Rect2:
	var x: float = _EDGE_PADDING + index * (_SLOT_SIZE.x + _SLOT_SPACING) - _scroll
	return Rect2(Vector2(x, _EDGE_PADDING), _SLOT_SIZE)

func _content_width() -> float:
	if _stacks.is_empty():
		return 0.0
	return _EDGE_PADDING * 2.0 + _stacks.size() * _SLOT_SIZE.x + (_stacks.size() - 1) * _SLOT_SPACING

func _clamp_scroll() -> void:
	var max_scroll: float = maxf(_content_width() - size.x, 0.0)
	_scroll = clampf(_scroll, 0.0, max_scroll)

func _draw() -> void:
	for index: int in _stacks.size():
		_draw_slot(index)

func _draw_slot(index: int) -> void:
	var stack: ItemStack = _stacks[index]
	var rect := _slot_rect(index)
	if rect.end.x < 0.0 or rect.position.x > size.x:
		return
	draw_rect(rect, _SLOT_BACKGROUND)
	var selected: bool = stack == _selected
	draw_rect(rect, _SELECTED_BORDER if selected else _SLOT_BORDER, false, 2.0 if selected else 1.0)
	if stack.item_blueprint != null:
		_draw_footprint(stack.item_blueprint, rect)
	_draw_quantity(stack.quantity, rect)

func _draw_footprint(blueprint: ItemBlueprint, slot: Rect2) -> void:
	var cells: Array[Vector2i] = blueprint.footprint_cells
	if cells.is_empty():
		return
	var span := Vector2i.ONE
	for cell: Vector2i in cells:
		span.x = maxi(span.x, cell.x + 1)
		span.y = maxi(span.y, cell.y + 1)
	var inner := slot.grow(-_SHAPE_INSET)
	var cell_size: float = minf(inner.size.x / span.x, inner.size.y / span.y)
	var origin := inner.position + (inner.size - Vector2(span) * cell_size) * 0.5
	var fill: Color = blueprint.color
	fill.a = 1.0
	for cell: Vector2i in cells:
		var cell_rect := Rect2(origin + Vector2(cell) * cell_size, Vector2(cell_size, cell_size) - Vector2(2.0, 2.0))
		draw_rect(cell_rect, fill)
		draw_rect(cell_rect, blueprint.color.lightened(0.4), false, 1.0)

func _draw_quantity(quantity: int, slot: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var text := "×%d" % quantity
	var position := slot.position + Vector2(8.0, slot.size.y - 8.0)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _QUANTITY_FONT_SIZE, Color(1, 1, 1, 0.85))
