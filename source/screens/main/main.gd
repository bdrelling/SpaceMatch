extends Node
## The bootstrapper — the app's entry point. Sets up scene loading, device orientation/safe area, and the
## window's content scaling, then transitions into the first screen (see [method _boot]). Holds no game state;
## every screen is its own scene reached from the menu.

# Portrait design resolution the responsive UI is authored against. Mobile scales the whole UI to fill the
# device screen from this base; desktop keeps the height and derives the width from the launched window's
# aspect so the portrait container matches the window exactly.
const _DESIGN_SIZE := Vector2i(1080, 1920)

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

	_apply_window(get_window())
	_boot()

## Opens the first screen. Debug builds — the editor's Play and every [code]make play[/code] target — drop
## straight into the [EncounterScreen] so every launch lands on the match we're iterating on; release builds
## land on the title screen ([MainMenuScreen]). A [code]--boot=<screen>[/code] launch flag overrides that
## default (menu, encounter, or loadout) for a one-off dev loop.
func _boot() -> void:
	var fallback: String = "encounter" if OS.is_debug_build() else "menu"
	match CommandLine.get_launch_argument_value("boot", fallback):
		"encounter":
			SceneLoader.transition_to(EncounterScreen.create())
		"loadout":
			SceneLoader.transition_to(LoadoutScreen.create())
		_:
			SceneLoader.transition_to(MainMenuScreen.create())

## Sets [param window]'s content scaling for the touch UI (canvas-items in both cases). The window's size
## and shape come entirely from the launch — the platform on a real device, the `make` targets' `--resolution`
## on desktop — and nothing is resized here. Mobile fills the device screen edge-to-edge (EXPAND); desktop
## locks to the launched window's aspect (KEEP) so it fills with no letterbox at launch, then letterboxes on
## resize rather than squashing the view square or landscape.
func _apply_window(window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if DeviceInfo.is_handheld():
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		window.content_scale_size = _DESIGN_SIZE
	else:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		var aspect: float = float(window.size.x) / float(window.size.y)
		window.content_scale_size = Vector2i(roundi(_DESIGN_SIZE.y * aspect), _DESIGN_SIZE.y)
