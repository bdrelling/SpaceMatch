# res://autoload/focus_guard.gd
extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true

var _focused := true

func _input(_event: InputEvent) -> void:
	if not _focused:
		get_viewport().set_input_as_handled()
