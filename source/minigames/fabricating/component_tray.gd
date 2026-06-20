class_name ComponentTray
extends Control
## The fabricating component tray: one slot per component kind the recipe still needs, showing its colour,
## name, and remaining count. Tapping a slot with stock left picks that component up to place on the board.

signal component_picked(kind: int)

const _SLOT := Vector2(110.0, 110.0)
const _GAP := 12.0

var _entries: Array[Entry] = []
var _selected_kind: int = -1

func set_entries(entries: Array[Entry]) -> void:
	_entries = entries
	update_minimum_size()
	queue_redraw()

func set_selected(kind: int) -> void:
	_selected_kind = kind
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var position := Vector2.INF
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			position = mouse.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch.index == 0:
			position = touch.position
	if position == Vector2.INF:
		return
	var index := int(position.x / (_SLOT.x + _GAP))
	if index < 0 or index >= _entries.size():
		return
	var entry := _entries[index]
	if entry.remaining > 0:
		component_picked.emit(entry.kind)
		accept_event()

func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	for index in _entries.size():
		var entry := _entries[index]
		var origin := Vector2(index * (_SLOT.x + _GAP), 0.0)
		var rect := Rect2(origin, _SLOT)
		draw_rect(rect, Color(0.12, 0.15, 0.22))
		var border: Color = Color(0.9, 0.75, 0.3) if entry.kind == _selected_kind else Color(0.3, 0.35, 0.47)
		draw_rect(rect, border, false, 2.0)
		draw_rect(Rect2(origin + Vector2(18.0, 16.0), Vector2(_SLOT.x - 36.0, _SLOT.y - 48.0)), entry.color)
		draw_string(
			font, origin + Vector2(8.0, _SLOT.y - 10.0),
			"%s ×%d" % [entry.label, entry.remaining],
			HORIZONTAL_ALIGNMENT_CENTER, _SLOT.x - 16.0, font_size)

func _get_minimum_size() -> Vector2:
	if _entries.is_empty():
		return Vector2(0.0, _SLOT.y)
	return Vector2(_entries.size() * (_SLOT.x + _GAP) - _GAP, _SLOT.y)

## One tray slot: a component kind, its swatch colour and name, and how many the recipe still needs.
class Entry:
	var kind: int
	var color: Color
	var label: String
	var remaining: int

	func _init(_kind: int, _color: Color, _label: String, _remaining: int) -> void:
		kind = _kind
		color = _color
		label = _label
		remaining = _remaining
