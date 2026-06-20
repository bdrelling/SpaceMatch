extends GdUnitTestSuite
## Covers [OverlayPanel]'s input policy — opening claims the configured block on
## [ManagedInput]; closing or leaving the tree releases it — and its toggle input,
## driving the raw [Input] singleton and calling [code]_unhandled_input[/code] per
## event the way the viewport does (exempted in [code]test_no_raw_input.gd[/code]).

const _JUMP := &"jump"
const _SPRINT := &"sprint"

# Registered in [InputMap] per test: project actions are absent in gdUnit's -s runs.
const _TOGGLE := &"overlay_panel_test_toggle"

func before_test() -> void:
	if not InputMap.has_action(_TOGGLE):
		InputMap.add_action(_TOGGLE)
		var binding := InputEventJoypadButton.new()
		binding.button_index = JOY_BUTTON_Y
		InputMap.action_add_event(_TOGGLE, binding)

func after_test() -> void:
	Input.action_release(_TOGGLE)
	if InputMap.has_action(_TOGGLE):
		InputMap.erase_action(_TOGGLE)

func _make_panel(policy: OverlayPanel.InputPolicy) -> OverlayPanel:
	var panel: OverlayPanel = auto_free(OverlayPanel.new())
	panel.input_policy = policy
	panel.add_child(Control.new())
	add_child(panel)
	return panel

func _toggle_press() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_Y
	event.pressed = true
	return event

func _stick_motion() -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = 0.7
	return event

func test_allow_all_leaves_input_unblocked() -> void:
	var panel := _make_panel(OverlayPanel.InputPolicy.ALLOW_ALL)
	panel.open()
	assert_bool(ManagedInput._is_action_blocked(_JUMP)).is_false()
	panel.close()

func test_block_all_claims_while_open() -> void:
	var panel := _make_panel(OverlayPanel.InputPolicy.BLOCK_ALL)
	panel.open()
	assert_bool(ManagedInput._is_action_blocked(_JUMP)).is_true()
	panel.close()
	assert_bool(ManagedInput._is_action_blocked(_JUMP)).is_false()

func test_block_actions_claims_only_listed() -> void:
	var panel := _make_panel(OverlayPanel.InputPolicy.BLOCK_ACTIONS)
	var blocked: Array[StringName] = [_JUMP]
	panel.blocked_actions = blocked
	panel.open()
	assert_bool(ManagedInput._is_action_blocked(_JUMP)).is_true()
	assert_bool(ManagedInput._is_action_blocked(_SPRINT)).is_false()
	panel.close()

func test_exiting_tree_releases_block() -> void:
	var panel := _make_panel(OverlayPanel.InputPolicy.BLOCK_ALL)
	panel.open()
	assert_bool(ManagedInput._is_action_blocked(_JUMP)).is_true()
	remove_child(panel)
	assert_bool(ManagedInput._is_action_blocked(_JUMP)).is_false()

func test_press_toggles_open() -> void:
	var panel := _make_panel(OverlayPanel.InputPolicy.ALLOW_ALL)
	panel.toggle_action = _TOGGLE
	Input.action_press(_TOGGLE)
	panel._unhandled_input(_toggle_press())
	assert_bool(panel.is_open).is_true()

## A gamepad press rarely arrives alone: while the stick is held, motion events land in
## the same frame. Each one re-enters _unhandled_input while is_action_just_pressed is
## still true for the frame, so a polled read toggles the panel once per event — an even
## count closes it right back, reading as a dropped press. Only the press event may fire.
func test_trailing_same_frame_event_does_not_retoggle() -> void:
	var panel := _make_panel(OverlayPanel.InputPolicy.ALLOW_ALL)
	panel.toggle_action = _TOGGLE
	Input.action_press(_TOGGLE)
	panel._unhandled_input(_toggle_press())
	panel._unhandled_input(_stick_motion())
	assert_bool(panel.is_open).is_true()
