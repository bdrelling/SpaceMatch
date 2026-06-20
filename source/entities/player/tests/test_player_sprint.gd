extends GdUnitTestSuite
## Covers the gamepad sprint latch ([enum Player.SprintMode]): only gamepad presses
## latch, only in TOGGLE mode, and a latched sprint drops its latch when it ends.

var _player: Player

func before_test() -> void:
	# Kept out of the tree: these tests call _unhandled_input/_update_sprinting
	# directly, and _ready expects a wired camera the suite doesn't build.
	_player = Player.SCENE.instantiate()

func after_test() -> void:
	Settings.game.clear(GameSettings.KEY_SPRINT_MODE)
	_player.free()

func _sprint_gamepad_press() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_LEFT_STICK
	event.pressed = true
	return event

func _sprint_keyboard_press() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = true
	return event

func test_gamepad_press_latches_in_toggle_mode() -> void:
	Settings.game.sprint_mode = Player.SprintMode.TOGGLE
	_player._unhandled_input(_sprint_gamepad_press())
	assert_bool(_player._sprint_latched).is_true()
	_player._unhandled_input(_sprint_gamepad_press())
	assert_bool(_player._sprint_latched).is_false()

func test_gamepad_press_does_not_latch_in_hold_mode() -> void:
	Settings.game.sprint_mode = Player.SprintMode.HOLD
	_player._unhandled_input(_sprint_gamepad_press())
	assert_bool(_player._sprint_latched).is_false()

func test_keyboard_press_never_latches() -> void:
	Settings.game.sprint_mode = Player.SprintMode.TOGGLE
	_player._unhandled_input(_sprint_keyboard_press())
	assert_bool(_player._sprint_latched).is_false()

func test_latch_drops_when_sprint_ends() -> void:
	# Latched and sprinting with no movement input: the sprint ends and takes the latch with it.
	_player._sprint_latched = true
	_player._sprinting = true
	_player._update_sprinting()
	assert_bool(_player.is_sprinting()).is_false()
	assert_bool(_player._sprint_latched).is_false()

func test_latch_survives_before_sprint_starts() -> void:
	# Latched but not yet sprinting (e.g. mid-air after a sprint-jump): the latch waits.
	_player._sprint_latched = true
	_player._sprinting = false
	_player._update_sprinting()
	assert_bool(_player._sprint_latched).is_true()
