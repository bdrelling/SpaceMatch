extends Node

func _ready() -> void:
	SceneLoader.set_scene_container(self)
	_show_initial_scene()

# [BootConfig] picks the entry scene and orientation from the command line (`--mode=`,
# `--orientation=`) or the platform default: mobile/web boot the 2D [Arcade], desktop the 3D [Overworld].
# Each scene is lazy-loaded in its own `create()`, so only the chosen one is ever pulled into memory.
func _show_initial_scene() -> void:
	var config: BootConfig = BootConfig.resolve()
	DeviceUtils.set_orientation(config.orientation)
	match config.mode:
		BootConfig.Mode.ARCADE:
			# The window's portrait size and shape come from the launch (the platform on a device, the
			# `make arcade` targets' flags on desktop); this only sets responsive content scaling. No
			# resize, so no flash.
			Arcade.apply_window(get_window())
			SceneLoader.transition_to(Arcade.create())
		BootConfig.Mode.GAME:
			SceneLoader.transition_to(Overworld.create())
