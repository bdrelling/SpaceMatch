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

## Opens the first screen. Every launch drops straight into the [EncounterScreen] — the match we're
## iterating on — so on-device rapid testing lands there just like [code]make play[/code], regardless of
## debug/release. A [code]--boot=<screen>[/code] launch flag overrides it (menu, encounter, or loadout);
## the title screen ([MainMenuScreen]) becomes the default once the menu is the real entry point.
func _boot() -> void:
	var fallback: String = EncounterScreen.SCREEN_NAME
	match CommandLine.get_launch_argument_value("boot", fallback):
		EncounterScreen.SCREEN_NAME:
			SceneLoader.transition_to(EncounterScreen.create())
		MainMenuScreen.SCREEN_NAME:
			SceneLoader.transition_to(MainMenuScreen.create())
		_:
			# TODO: THIS SHOULD BE AN ERROR SCREEN!
			SceneLoader.transition_to(MainMenuScreen.create())

## Sets [param window]'s content scaling for the touch UI (canvas-items in every case). On a REAL phone or
## tablet the screen IS the device, so the UI fills it edge-to-edge (EXPAND) with no aspect bounding; the
## export pins orientation. On desktop — a plain window or a `--device` preview — the window is arbitrary, so
## the UI is bound (KEEP, letterboxed) to a fixed aspect: the previewed device's for a phone/tablet preview,
## or the 9:16 design for a plain window. See [method _update_desktop_scale_size].
func _apply_window(window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if OS.has_feature("mobile"):
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		window.content_scale_size = _DESIGN_SIZE
	else:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		_update_desktop_scale_size()
		window.size_changed.connect(_update_desktop_scale_size)

## Desktop only. Binds content_scale_size to a fixed aspect at the design height — the previewed device's
## (phone/tablet) or the 9:16 design for a plain window — flipped to portrait or landscape to match the
## window, so KEEP letterboxes any off-aspect window instead of stretching. Constant within an orientation,
## so a resize drag doesn't churn. Real devices use EXPAND and never call this — iPhone/iPad are untouched.
func _update_desktop_scale_size() -> void:
	var window := get_window()
	var base := _preview_base_size()
	var portrait := window.size.y > window.size.x
	var aspect := (float(base.x) / float(base.y)) if portrait else (float(base.y) / float(base.x))
	var size := Vector2i(roundi(_DESIGN_SIZE.y * aspect), _DESIGN_SIZE.y)
	if window.content_scale_size != size:
		window.content_scale_size = size

## The portrait base whose aspect a desktop window binds to: the previewed device's points for a
## `--device=phone`/`tablet` launch, else the 9:16 design size for a plain desktop window.
func _preview_base_size() -> Vector2i:
	var device := DeviceInfo.device_type()
	if DeviceUtils.DEVICE_RESOLUTIONS.has(device):
		var points: Vector2 = DeviceUtils.DEVICE_RESOLUTIONS[device]
		return Vector2i(points)
	return _DESIGN_SIZE
