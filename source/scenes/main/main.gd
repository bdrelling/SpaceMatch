extends Node

func _ready() -> void:
	SceneLoader.set_scene_container(self)
	var orientation: DeviceUtils.Orientation = CommandLine.get_launch_option(
		"orientation", DeviceUtils.ORIENTATION_NAMES, DeviceUtils.get_default_orientation()
	)
	DeviceUtils.set_orientation(orientation)

	# Size the desktop window to the launched device: flag → enum → resolution, using DeviceUtils as
	# the source of truth. The Makefile's --resolution just boots at the same size.
	if CommandLine.has_launch_argument_key("device"):
		var device: DeviceUtils.DeviceType = CommandLine.get_launch_option(
			"device", DeviceUtils.DEVICE_TYPE_NAMES, DeviceUtils.DeviceType.DESKTOP
		)
		if DeviceUtils.DEVICE_RESOLUTIONS.has(device):
			var points: Vector2 = DeviceUtils.DEVICE_RESOLUTIONS[device]
			get_window().size = Vector2i((points * DeviceUtils.get_preview_scale(device)).round())

	Game.apply_window(get_window())
	# Boots straight into the game for a fast dev loop. Eventually this lands on the title screen first
	# (`SceneLoader.transition_to(MainMenu.create())`), which Play then advances into the game.
	SceneLoader.transition_to(Game.create())
