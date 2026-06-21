extends GdUnitTestSuite
## The Game shell: the idle clock drips into the session-bound inventory, two screens bound
## to one session see the same change, and the whole shell is 2D — no [Node3D] anywhere (it's the
## no-3D production entry, not the [Overworld]).

func _blueprint(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func test_clock_emits_and_counts_ticks() -> void:
	var clock := Clock.new()
	clock.autostart = false
	add_child(clock)
	var counts: Array[int] = []
	clock.ticked.connect(func(count: int) -> void: counts.append(count))
	clock.tick()
	clock.tick()
	# The source counts ticks and emits each one; responders (none here) decide what to do with them.
	assert_array(counts).is_equal([1, 2])
	assert_int(clock.count).is_equal(2)
	clock.queue_free()

func test_two_screens_share_one_session_inventory() -> void:
	var session := GameSession.new_game()
	var inventory := Inventory.new()
	add_child(inventory)
	session.bind_inventory(inventory)
	var screen_a := StageScreen.new()
	var screen_b := StageScreen.new()
	add_child(screen_a)
	add_child(screen_b)
	screen_a.bind(session, inventory)
	screen_b.bind(session, inventory)

	var no_tags: Array[Item.Tag] = []
	inventory.add_variant(_blueprint(7), no_tags, 3)

	# One change to the shared inventory shows on both screens — they're not separate copies.
	assert_str(screen_a.summary()).contains("× 3")
	assert_str(screen_b.summary()).contains("× 3")
	screen_a.queue_free()
	screen_b.queue_free()
	inventory.queue_free()

func test_game_boots_a_session_and_is_2d_only() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	assert_object(game.session).is_not_null()
	assert_bool(_has_node3d(game)).override_failure_message(
		"Game must be 2D-only, but a Node3D was found in its tree.").is_false()
	game.queue_free()

func test_pager_has_every_stage_and_settings() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	var titles: Array[String] = []
	for screen: GameScreen in game._pager.screens:
		titles.append(screen.title)
	# Order is the scene's business; the shell just has to surface every stage and Settings.
	assert_array(titles).contains_exactly_in_any_order(
		["Recycling", "Outfitting", "Settings"])
	game.queue_free()

func test_selecting_a_tab_pages_to_it() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	# Tapping a stage tab (emitting its index) pages to that stage.
	game._tab_bar.tab_selected.emit(1)
	assert_bool(game._pager.screens[1].visible).is_true()
	assert_bool(game._pager.screens[0].visible).is_false()
	game.queue_free()

func test_settings_cog_pages_to_settings() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	# Settings is not a tab — the top-bar cog opens it, and the tab highlight clears.
	game._top_bar.settings_pressed.emit()
	var settings_index := -1
	for index: int in game._pager.screens.size():
		if game._pager.screens[index].title == "Settings":
			settings_index = index
	assert_int(settings_index).is_greater_equal(0)
	assert_bool(game._pager.screens[settings_index].visible).is_true()
	game.queue_free()

func test_trackpad_pan_pages_between_screens() -> void:
	var pager := GamePager.new()
	add_child(pager)
	pager.add_screen(StageScreen.new())
	pager.add_screen(StageScreen.new())
	# A horizontal two-finger pan past the threshold advances a page; the reverse pages back.
	var forward := InputEventPanGesture.new()
	forward.delta = Vector2(-100.0, 0.0)
	pager._unhandled_input(forward)
	assert_bool(pager.screens[1].visible).is_true()
	var back := InputEventPanGesture.new()
	back.delta = Vector2(100.0, 0.0)
	pager._unhandled_input(back)
	assert_bool(pager.screens[0].visible).is_true()
	pager.queue_free()

func test_keyboard_arrows_do_not_page() -> void:
	# Left/right are reserved for a minigame's own controls (e.g. a falling piece) — the pager must
	# page only on swipe/pan/wheel, never on the keyboard.
	var pager := GamePager.new()
	add_child(pager)
	pager.add_screen(StageScreen.new())
	pager.add_screen(StageScreen.new())
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	pager._unhandled_input(right)
	assert_bool(pager.screens[0].visible).is_true()
	assert_bool(pager.screens[1].visible).is_false()
	pager.queue_free()

func test_tabs_are_not_keyboard_focusable() -> void:
	# Focusable tab buttons would let arrow keys walk focus across the tabs, stealing left/right from
	# the minigame; the tabs are tap/swipe-driven only — authored FOCUS_NONE in the scene.
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	var tabs := game._tab_bar.tab_buttons()
	for button: Button in tabs:
		assert_int(button.focus_mode).is_equal(Control.FOCUS_NONE)
	# The tab bar authors one button per stage; Settings is the cog, not a tab.
	assert_int(tabs.size()).is_equal(6)
	game.queue_free()

func test_minigame_screens_do_not_block_board_input() -> void:
	# A minigame screen must stay transparent to pointer input, or its board's
	# taps/swipes never reach the minigame's own gesture handling (regression:
	# wrapping the board in default-STOP containers swallowed every tap).
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	var minigame_screens := 0
	for screen: GameScreen in game._pager.screens:
		if screen is MinigameScreen:
			minigame_screens += 1
			assert_int(screen.mouse_filter).override_failure_message(
				"MinigameScreen '%s' must be MOUSE_FILTER_IGNORE so board input passes through." % screen.title
			).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(minigame_screens).is_equal(2)
	game.queue_free()

func test_restart_replaces_the_session() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	var first := game.session
	game.restart()
	assert_object(game.session).is_not_same(first)
	game.queue_free()

func _has_node3d(node: Node) -> bool:
	if node is Node3D:
		return true
	for child: Node in node.get_children():
		if _has_node3d(child):
			return true
	return false
