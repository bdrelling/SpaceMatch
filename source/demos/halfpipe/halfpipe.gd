@tool
class_name Halfpipe
extends GameLevel
## Standalone demo scene with a single large static skatepark half-pipe.

@onready var _player: Player = %Player

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_player.position = spawn_marker.position
	_player.snap_camera()
