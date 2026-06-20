class_name Overworld
extends Node

#region Constants

## Loaded on demand in [method create] rather than `preload`-ed, so merely
## referencing [Overworld] never pulls the 3D scene into memory — only an actual
## [method create] call does.
const SCENE_PATH := "res://scenes/overworld/overworld.tscn"

#endregion

#region Properties

@export var level: GameLevel
@export var camera: PlayerCamera
@export var player: Player

## The running game's live state. A fresh single-player game here; the player's inventory binds to
## its [PlayerState] so the 3D game runs on the same [GameSession] the Arcade will.
var session: GameSession

#endregion

#region Lifecycle

func _ready() -> void:
	session = GameSession.new_game()
	session.bind_inventory(player.inventory, 0)
	spawn_player()

#endregion

#region Methods

func spawn_player() -> void:
	player.global_position = level.spawn_marker.global_position
	player.snap_camera()

static func create() -> Overworld:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()

#endregion
