extends GdUnitTestSuite
## Covers [ManagedInput]'s claim-based action blocking. Drives the raw [Input]
## singleton to simulate held actions — exempted in [code]test_no_raw_input.gd[/code].

const _JUMP := &"jump"
const _SPRINT := &"sprint"

# Registered in [InputMap] per test: project actions are absent in gdUnit's -s runs,
# and the unblock latch enumerates [InputMap] actions for block-all claims.
const _TEST_ACTION := &"managed_input_test_action"

func before_test() -> void:
	# Project actions are absent in gdUnit's -s runs, so register every action this suite
	# drives; and a prior suite may have left ManagedInput holding a block claim — clear it
	# so the first test isn't suppressed by leaked state.
	for action: StringName in [_TEST_ACTION, _JUMP, _SPRINT, &"move_forward", &"move_backward"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	ManagedInput._blocked_actions.clear()
	ManagedInput._held_through_unblock.clear()

func after_test() -> void:
	Input.action_release(_JUMP)
	Input.action_release(_SPRINT)
	Input.action_release(&"move_forward")
	Input.action_release(_TEST_ACTION)
	ManagedInput._blocked_actions.clear()
	ManagedInput._held_through_unblock.clear()
	if InputMap.has_action(_TEST_ACTION):
		InputMap.erase_action(_TEST_ACTION)

func test_block_all_suppresses_every_action() -> void:
	var claimant := RefCounted.new()
	Input.action_press(_JUMP)
	assert_bool(ManagedInput.is_action_pressed(_JUMP)).is_true()

	ManagedInput.block_actions(claimant)
	assert_bool(ManagedInput.is_action_pressed(_JUMP)).is_false()

	ManagedInput.unblock_actions(claimant)
	assert_bool(ManagedInput.is_action_pressed(_JUMP)).is_true()

func test_block_actions_suppresses_only_listed() -> void:
	var claimant := RefCounted.new()
	Input.action_press(_JUMP)
	Input.action_press(_SPRINT)

	var blocked: Array[StringName] = [_JUMP]
	ManagedInput.block_actions(claimant, blocked)
	assert_bool(ManagedInput.is_action_pressed(_JUMP)).is_false()
	assert_bool(ManagedInput.is_action_pressed(_SPRINT)).is_true()

func test_axis_zeroes_when_either_side_blocked() -> void:
	var claimant := RefCounted.new()
	Input.action_press(&"move_forward")
	assert_float(ManagedInput.get_axis(&"move_backward", &"move_forward")).is_equal(1.0)

	var blocked: Array[StringName] = [&"move_forward"]
	ManagedInput.block_actions(claimant, blocked)
	assert_float(ManagedInput.get_axis(&"move_backward", &"move_forward")).is_equal(0.0)

func test_press_held_through_unblock_suppresses_just_pressed() -> void:
	var claimant := RefCounted.new()
	ManagedInput.block_actions(claimant) # Block-all, as an exclusive panel does.
	Input.action_press(_TEST_ACTION) # The press that dismisses the claimant.
	ManagedInput.unblock_actions(claimant)

	assert_bool(ManagedInput.is_action_just_pressed(_TEST_ACTION)).is_false()
	# Held continuous reads stay live so e.g. movement resumes immediately.
	assert_bool(ManagedInput.is_action_pressed(_TEST_ACTION)).is_true()

func test_held_through_unblock_clears_on_release() -> void:
	var claimant := RefCounted.new()
	var blocked: Array[StringName] = [_TEST_ACTION]
	ManagedInput.block_actions(claimant, blocked)
	Input.action_press(_TEST_ACTION)
	ManagedInput.unblock_actions(claimant)
	assert_bool(ManagedInput.is_action_just_pressed(_TEST_ACTION)).is_false()

	Input.action_release(_TEST_ACTION)
	# Raw Input keeps a same-frame press+release "just pressed" (tap memory), which
	# can't happen across real frames — step one before reading.
	await await_idle_frame()
	assert_bool(ManagedInput.is_action_just_pressed(_TEST_ACTION)).is_false()
	Input.action_press(_TEST_ACTION)
	assert_bool(ManagedInput.is_action_just_pressed(_TEST_ACTION)).is_true()

func test_dead_claimant_does_not_block() -> void:
	var claimant := Node.new()
	ManagedInput.block_actions(claimant)
	claimant.free()

	Input.action_press(_JUMP)
	assert_bool(ManagedInput.is_action_pressed(_JUMP)).is_true()
