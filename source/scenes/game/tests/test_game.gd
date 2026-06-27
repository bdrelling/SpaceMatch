extends GdUnitTestSuite
## The Game shell: the idle clock counts ticks and the whole shell is 2D — no [Node3D] anywhere
## (it's the no-3D production entry, not the [Overworld]).

func after_test() -> void:
	# Defensive: the settings-overlay flows pause the shared tree — never leave it paused for the
	# next test, even if an assertion above bailed before unpausing.
	get_tree().paused = false

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

func test_game_boots_a_session_and_is_2d_only() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	assert_object(GameSession.game_state).is_not_null()
	assert_bool(_has_node3d(game)).override_failure_message(
		"Game must be 2D-only, but a Node3D was found in its tree.").is_false()
	game.queue_free()

func test_pager_has_every_stage() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	var titles: Array[String] = []
	for screen: GameScreen in game._pager.screens:
		titles.append(screen.title)
	# Settings is a top-most overlay now, not a page — the pager holds only the playable stages.
	assert_array(titles).contains_exactly_in_any_order(["Match", "Loadout"])
	game.queue_free()

func test_drill_into_loadout_and_back() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	# The primary stage drills into Loadout via its own drill request (the HUD "Player" box),
	# handing the shell the combatant whose loadout to show.
	var match_screen := game._pager.screens[0] as MinigameScreen
	match_screen.minigame().drill_requested.emit(GameSession.game_state.starship)
	assert_bool(game._pager.screens[1].visible).is_true()
	assert_bool(game._pager.screens[0].visible).is_false()
	# ...and the top-bar back button steps back to the primary stage.
	game._top_bar.leading_pressed.emit()
	assert_bool(game._pager.screens[0].visible).is_true()
	assert_bool(game._pager.screens[1].visible).is_false()
	game.queue_free()

func test_settings_cog_opens_the_overlay() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	# Settings is not a tab — the top-bar cog opens it as a top-most overlay (by pausing the game).
	assert_bool(game._settings_overlay.visible).is_false()
	game._top_bar.settings_pressed.emit()
	assert_bool(game._settings_overlay.visible).is_true()
	# The cog paused the shared tree to open the overlay — resume before freeing, or the deferred
	# free can't flush on a paused tree and the game subtree leaks as an orphan.
	PauseMonitor.unpause()
	game.queue_free()

func test_pause_opens_and_closes_the_settings_overlay() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	# The pause action drives the overlay: pausing shows it over the frozen game, resuming hides it.
	assert_bool(game._settings_overlay.visible).is_false()
	PauseMonitor.pause()
	assert_bool(game._settings_overlay.visible).is_true()
	PauseMonitor.unpause()
	assert_bool(game._settings_overlay.visible).is_false()
	game.queue_free()

func test_settings_resume_button_resumes_and_closes() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	PauseMonitor.pause()
	var settings := game._settings_overlay.get_node("Settings") as SettingsScreen
	# Resume is the screen's exit — it resumes the game, which hides the overlay.
	settings._resume_button.pressed.emit()
	assert_bool(PauseMonitor.is_paused).is_false()
	assert_bool(game._settings_overlay.visible).is_false()
	game.queue_free()

func test_settings_restart_button_resumes_and_replaces_session() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	var first := GameSession.game_state
	PauseMonitor.pause()
	var settings := game._settings_overlay.get_node("Settings") as SettingsScreen
	# Restart from the panel resumes the game and rebuilds the session in place.
	settings._restart_button.pressed.emit()
	assert_bool(PauseMonitor.is_paused).is_false()
	assert_object(GameSession.game_state).is_not_same(first)
	game.queue_free()

func test_settings_quit_button_is_wired_to_the_shell() -> void:
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	var settings := game._settings_overlay.get_node("Settings") as SettingsScreen
	# Quit transitions out through the real SceneLoader (which would free the test's current scene), so
	# the press isn't fired here — assert the screen's signal reaches the shell's quit handler instead.
	assert_bool(settings.quit_pressed.is_connected(game._on_settings_quit)).is_true()
	game.queue_free()

func test_settings_screen_buttons_emit_owner_actions() -> void:
	# The screen only emits Restart/Quit; the shell acts on them. Verified on a standalone screen so no
	# shell handler is attached to fire the real (scene-changing) quit.
	var settings := (load("res://scenes/game/screens/settings_screen/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
	add_child(settings)
	await await_idle_frame()
	var fired := {"restart": false, "quit": false}
	settings.restart_pressed.connect(func() -> void: fired["restart"] = true)
	settings.quit_pressed.connect(func() -> void: fired["quit"] = true)
	settings._restart_button.pressed.emit()
	settings._quit_button.pressed.emit()
	assert_bool(fired["restart"]).is_true()
	assert_bool(fired["quit"]).is_true()
	settings.queue_free()

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

func test_top_bar_buttons_are_not_keyboard_focusable() -> void:
	# Focusable bar buttons would let arrow keys walk focus across them, stealing left/right from
	# the minigame; the leading and settings buttons are tap-driven only — authored FOCUS_NONE.
	var game := Game.create()
	add_child(game)
	await await_idle_frame()
	for button: Button in [game._top_bar._leading, game._top_bar._settings]:
		assert_int(button.focus_mode).is_equal(Control.FOCUS_NONE)
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
	var first := GameSession.game_state
	game.restart()
	assert_object(GameSession.game_state).is_not_same(first)
	game.queue_free()

func _has_node3d(node: Node) -> bool:
	if node is Node3D:
		return true
	for child: Node in node.get_children():
		if _has_node3d(child):
			return true
	return false
