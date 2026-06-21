class_name SafeAreaOverlay
extends SafeAreaContainer
## Debug overlay that draws the launched device's safe area (`--device`) so the notch / home-indicator
## region is visible in the desktop preview. Inert until [member is_debug_enabled] is toggled on.

func _ready() -> void:
	# Purely visual — never intercept input meant for the game beneath it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CommandLine.has_launch_argument_key("device"):
		_simulated_device = CommandLine.get_launch_option(
			"device", DeviceUtils.DEVICE_TYPE_NAMES, DeviceUtils.DeviceType.DESKTOP
		)
	super()
