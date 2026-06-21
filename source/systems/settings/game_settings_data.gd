class_name GameSettingsData
extends Resource
## Typed schema and shipped defaults for the [code]game[/code] settings group.
##
## The hot-swappable defaults live in [code]game_settings_defaults.tres[/code];
## [GameSettings] loads that file as the fallback for any preference the player
## has not explicitly overridden.

# No game-specific settings yet — the 3D camera/player options (camera_mode,
# invert_y_axis, sprint_mode) were removed with the overworld. Add 2D game
# settings here as they arrive.
