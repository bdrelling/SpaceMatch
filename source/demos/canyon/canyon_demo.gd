@tool
class_name CanyonDemo
extends GameLevel
## Standalone demo scene for a procedural downhill canyon run.
##
## Instantiates the player, camera, atmosphere, and a CanyonManager that
## generates winding canyon chunks ahead of the player.

@onready var _player: Player = %Player
@onready var _canyon_manager: CanyonManager = %CanyonManager

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_player.position = spawn_marker.position
	_player.snap_camera()
	_canyon_manager.setup(_player)
