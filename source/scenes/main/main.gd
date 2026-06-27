extends Node

func _ready() -> void:
	SceneLoader.set_scene_container(self)
	var orientation: DeviceUtils.Orientation = CommandLine.get_launch_option(
		"orientation", DeviceUtils.ORIENTATION_NAMES, DeviceUtils.get_default_orientation()
	)
	DeviceUtils.set_orientation(orientation)

	# Every SafeAreaContainer simulates this device's notch on desktop previews; -1 on real hardware,
	# where each reads its own live OS safe area. Set once here so the addon needs no launch-flag knowledge.
	SafeAreaContainer.default_simulated_device = DeviceInfo.simulated_device()

	# Size the desktop window to the launched device: flag → enum → resolution, using DeviceUtils as
	# the source of truth. The Makefile's --resolution just boots at the same size.
	if CommandLine.has_launch_argument_key("device"):
		var device := DeviceInfo.device_type()
		if DeviceUtils.DEVICE_RESOLUTIONS.has(device):
			var points: Vector2 = DeviceUtils.DEVICE_RESOLUTIONS[device]
			get_window().size = Vector2i((points * DeviceUtils.get_preview_scale(device)).round())

	Game.apply_window(get_window())
	# Boots straight into the game for a fast dev loop. Eventually this lands on the title screen first
	# (`SceneLoader.transition_to(MainMenu.create())`), which Play then advances into the game.
	SceneLoader.transition_to(Game.create())
