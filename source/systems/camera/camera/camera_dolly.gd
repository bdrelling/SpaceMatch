class_name CameraDolly
extends Node

signal position_changed(position: CameraPosition)

@export var camera: Camera3D
@export var current_index := 0
@export var positions: Array[CameraPosition]
	
func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()

func _unhandled_input(event: InputEvent) -> void:
	# We only care about the press event, not the release
	if not event.is_pressed(): return
	
	# We only care about key events
	var key_event := event as InputEventKey
	if not key_event: return
	
	# We only care about numbers 1-9
	var keycode := key_event.keycode
	if keycode < KEY_1 or keycode > KEY_9: return
	
	# Get our array index by subtracting the lowest applicable keycode
	var index := keycode - KEY_1
	if index >= positions.size(): return
	
	set_position_index(index)

func set_position_index(index: int) -> void:
	if index >= positions.size(): return
	
	var new_position := positions[index]
	if not new_position: 
		Log.warning("Error setting Camera Position; no position found at index %d" % index)
		return
		
	current_index = index
	set_position(new_position)
	
func set_position(camera_position: CameraPosition) -> void:
	camera.transform = camera_position.transform
	camera.projection = camera_position.projection_type
	position_changed.emit(camera_position)
	
