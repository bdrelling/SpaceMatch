extends GdUnitTestSuite
## Covers the collect rate limit ([constant Player.COLLECT_REPEAT_INTERVAL]): an interact press
## arms a repeat that keeps collecting on an interval while the button stays held, and rapid
## presses can't collect faster than the same interval — items only, a held button never
## re-triggers a [Structure]. Drives the raw [Input] singleton to simulate the held button —
## exempted in [code]test_no_raw_input.gd[/code].

var _player: Player
var _structure: Structure
var _structure_root: Node3D
var _interactions: int = 0

func before_test() -> void:
	# Kept out of the tree (like test_player_sprint.gd): these tests call
	# _unhandled_input/_update_held_collect directly, and _ready expects a wired
	# camera the suite doesn't build.
	_player = Player.SCENE.instantiate()
	_interactions = 0
	_structure = Structure.new()
	_structure.interacted.connect(func() -> void: _interactions += 1)
	_structure_root = Node3D.new()
	InteractionFocus.enter(_structure_root, _structure)

func after_test() -> void:
	Input.action_release(InputAction.INTERACT)
	InteractionFocus.clear()
	_player.free()
	_structure.free()
	_structure_root.free()

func _interact_press() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = InputAction.INTERACT
	event.pressed = true
	return event

func _press_and_hold() -> void:
	Input.action_press(InputAction.INTERACT)
	_player._unhandled_input(_interact_press())

func test_press_arms_hold_repeat() -> void:
	_press_and_hold()
	assert_bool(_player._collect_held).is_true()

func test_press_interacts_with_focused_structure() -> void:
	_press_and_hold()
	assert_int(_interactions).is_equal(1)

func test_hold_never_retriggers_structure() -> void:
	_press_and_hold()
	# Several full intervals elapse with the structure still focused: the repeat keeps firing
	# but the structure is never interacted with again.
	for i in 4:
		_player._update_collect(Player.COLLECT_REPEAT_INTERVAL)
	assert_int(_interactions).is_equal(1)

func test_interval_ticks_down_across_frames() -> void:
	_player._collect_repeat_timer = Player.COLLECT_REPEAT_INTERVAL
	_player._update_collect(Player.COLLECT_REPEAT_INTERVAL * 0.5)
	assert_float(_player._collect_repeat_timer).is_equal(Player.COLLECT_REPEAT_INTERVAL * 0.5)
	# The timer bottoms out at zero rather than banking negative time.
	_player._update_collect(Player.COLLECT_REPEAT_INTERVAL)
	assert_float(_player._collect_repeat_timer).is_equal(0.0)

func test_rapid_presses_cannot_beat_interval() -> void:
	var item := Item.new()
	item.blueprint = ItemBlueprint.new()
	# Mid-interval, the press is consumed (true — it must not fall through to a structure)
	# but nothing is collected: this player has no inventory wired, so reaching inventory.add
	# would crash. The held repeat picks the item up once the timer runs out.
	_player._collect_repeat_timer = Player.COLLECT_REPEAT_INTERVAL
	assert_bool(_player._collect_item(item)).is_true()
	item.free()

func test_release_disarms_repeat() -> void:
	_press_and_hold()
	Input.action_release(InputAction.INTERACT)
	_player._update_collect(Player.COLLECT_REPEAT_INTERVAL)
	assert_bool(_player._collect_held).is_false()
	assert_int(_interactions).is_equal(1)
