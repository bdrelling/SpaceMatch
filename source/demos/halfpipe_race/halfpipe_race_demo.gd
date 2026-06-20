@tool
class_name HalfpipeRaceDemo
extends GameLevel
## Standalone demo scene for a procedural downhill half-pipe.
##
## Instantiates the player, camera, lighting, and a HalfpipeRaceManager that
## generates winding half-pipe chunks ahead of the player.

const PLAYER_SPAWN_HEIGHT: float = 1.0

@export var chunk_scene: PackedScene

@onready var _player: Player = %Player
@onready var _halfpipe_race_manager: HalfpipeRaceManager = %HalfpipeRaceManager

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_player.position = Vector3(0.0, PLAYER_SPAWN_HEIGHT, 0.0)
	_player.snap_camera()
	_halfpipe_race_manager.setup(_player)
