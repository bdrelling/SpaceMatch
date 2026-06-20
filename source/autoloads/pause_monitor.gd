# AUTOLOAD: PauseMonitor
extends Node

signal paused
signal unpaused

var is_paused: bool:
	get: return get_tree().paused

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if ManagedInput.event_is_action_pressed(event, InputAction.PAUSE):
		toggle()

func pause() -> void:
	if not is_paused:
		get_tree().paused = true
		Log.debug("Game paused.")
		paused.emit()

func unpause() -> void:
	if is_paused:
		get_tree().paused = false
		Log.debug("Game unpaused.")
		unpaused.emit()

func toggle() -> void:
	if is_paused: unpause()
	else: pause()
