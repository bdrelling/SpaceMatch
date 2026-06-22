extends GdUnitTestSuite
## The title screen: Play drops into the game, Quit exits the app. Both drive the real SceneLoader / the
## tree, so the presses aren't fired here — the buttons and their wiring are asserted instead.

func test_main_menu_builds_with_play_and_quit() -> void:
	var menu := MainMenu.create()
	add_child(menu)
	await await_idle_frame()
	assert_object(menu._play_button).is_not_null()
	assert_object(menu._quit_button).is_not_null()
	menu.queue_free()

func test_play_and_quit_buttons_are_wired() -> void:
	var menu := MainMenu.create()
	add_child(menu)
	await await_idle_frame()
	assert_bool(menu._play_button.pressed.is_connected(menu._on_play_pressed)).is_true()
	assert_bool(menu._quit_button.pressed.is_connected(menu._on_quit_pressed)).is_true()
	menu.queue_free()
