class_name DebugPanel
extends RefCounted
## Base for one tab in the [DebugMenu]. Each subclass owns its own ImGui state and
## draws its tab body; the host owns the window, the tab bar, and the shared log.

var _menu: DebugMenu

func _init(menu: DebugMenu) -> void:
	_menu = menu

## Label shown on the tab.
func title() -> StringName:
	return &""

## Whether the tab appears this frame (target wired, etc.).
func is_available() -> bool:
	return true

## Draw the tab body — called between BeginTabItem/EndTabItem.
func draw() -> void:
	pass

# DragFloat bound to a single-element array; returns true when edited this frame.
func _drag_float(label: StringName, value: Array, step: float, min_value: float, max_value: float, fmt: String) -> bool:
	return ImGui.DragFloatEx(label, value, step, min_value, max_value, fmt, 0)

func _log(line: String) -> void:
	_menu.log_line(line)
