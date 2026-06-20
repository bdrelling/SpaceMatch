class_name GameSettingsData
extends Resource
## Typed schema and shipped defaults for the [code]game[/code] settings group.
##
## The hot-swappable defaults live in [code]game_settings_defaults.tres[/code];
## [GameSettings] loads that file as the fallback for any preference the player
## has not explicitly overridden.

@export var camera_mode: PlayerCamera.Mode = PlayerCamera.Mode.ORBIT_AND_CHASE
@export var invert_y_axis: bool = false
@export var sprint_mode: Player.SprintMode = Player.SprintMode.TOGGLE
