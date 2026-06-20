extends GdUnitTestSuite
## Verifies [JoypadLayout]'s swap retargets ui_accept/ui_cancel in the live [InputMap]
## in both directions, and leaves gameplay actions on their positional buttons.

## Stand-in for a gameplay action: project actions like [code]jump[/code] are not
## loaded in gdUnit's [code]-s[/code] runs, only the built-in [code]ui_*[/code] defaults.
const _GAMEPLAY_ACTION: StringName = &"joypad_layout_test_gameplay"

func before_test() -> void:
	JoypadLayout.set_swapped(false)

func after_test() -> void:
	JoypadLayout.set_swapped(false)
	if InputMap.has_action(_GAMEPLAY_ACTION):
		InputMap.erase_action(_GAMEPLAY_ACTION)

func test_swap_flips_confirm_cancel_and_restores() -> void:
	var bottom := InputEventJoypadButton.new()
	bottom.button_index = JOY_BUTTON_A
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_B

	assert_bool(InputMap.event_is_action(bottom, &"ui_accept")).is_true()
	assert_bool(InputMap.event_is_action(right, &"ui_cancel")).is_true()

	JoypadLayout.set_swapped(true)
	assert_bool(InputMap.event_is_action(right, &"ui_accept")).is_true()
	assert_bool(InputMap.event_is_action(bottom, &"ui_cancel")).is_true()
	assert_bool(InputMap.event_is_action(bottom, &"ui_accept")).is_false()

	JoypadLayout.set_swapped(false)
	assert_bool(InputMap.event_is_action(bottom, &"ui_accept")).is_true()
	assert_bool(InputMap.event_is_action(right, &"ui_cancel")).is_true()
	assert_bool(InputMap.event_is_action(right, &"ui_accept")).is_false()

func test_swap_leaves_gameplay_actions_positional() -> void:
	InputMap.add_action(_GAMEPLAY_ACTION)
	var stored := InputEventJoypadButton.new()
	stored.button_index = JOY_BUTTON_A
	InputMap.action_add_event(_GAMEPLAY_ACTION, stored)

	var bottom := InputEventJoypadButton.new()
	bottom.button_index = JOY_BUTTON_A

	JoypadLayout.set_swapped(true)
	assert_bool(InputMap.event_is_action(bottom, _GAMEPLAY_ACTION)).is_true()
