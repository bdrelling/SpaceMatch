# AUTOLOAD: TimeScaleManager
extends Node

## Array of time scale values to step through.
@export var time_scale_steps: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0]
## Input action name for incrementing time scale.
@export var increment_action: StringName = InputAction.TIME_SCALE_INCREASE
## Input action name for decrementing time scale.
@export var decrement_action: StringName = InputAction.TIME_SCALE_DECREASE
## Input action name for setting time scale to max.
@export var max_action: StringName = InputAction.TIME_SCALE_MAX
## Input action name for resetting time scale to default.
@export var reset_action: StringName = InputAction.TIME_SCALE_RESET

signal time_scale_changed(new_scale: float)

var _default_index: int = 2
var _current_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_time_scale()

func _unhandled_input(event: InputEvent) -> void:
	if ManagedInput.event_is_action_pressed(event, reset_action):
		_reset_time_scale()
	elif ManagedInput.event_is_action_pressed(event, max_action):
		_set_max_time_scale()
	elif ManagedInput.event_is_action_pressed(event, decrement_action):
		_decrement_time_scale()
	elif ManagedInput.event_is_action_pressed(event, increment_action):
		_increment_time_scale()

func _increment_time_scale() -> void:
	if _current_index < time_scale_steps.size() - 1:
		_current_index += 1
		_update_time_scale()

func _decrement_time_scale() -> void:
	if _current_index > 0:
		_current_index -= 1
		_update_time_scale()

func _set_max_time_scale() -> void:
	if time_scale_steps.size() > 0:
		_current_index = time_scale_steps.size() - 1
		_update_time_scale()

func _reset_time_scale() -> void:
	_current_index = _default_index
	_update_time_scale()

func _update_time_scale() -> void:
	if _current_index >= 0 and _current_index < time_scale_steps.size():
		Engine.time_scale = time_scale_steps[_current_index]
		time_scale_changed.emit(Engine.time_scale)
