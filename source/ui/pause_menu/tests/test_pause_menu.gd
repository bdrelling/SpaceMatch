extends GdUnitTestSuite

const PAUSE_MENU_SCENE: PackedScene = preload("res://ui/pause_menu/pause_menu.tscn")
const MAIN_PANEL_SCENE: PackedScene = preload("res://ui/pause_menu/panels/pause_menu_main_panel.tscn")
const SETTINGS_PANEL_SCENE: PackedScene = preload("res://ui/pause_menu/panels/pause_menu_settings_panel.tscn")

func _instance_menu() -> PauseMenu:
	var menu: PauseMenu = auto_free(PAUSE_MENU_SCENE.instantiate())
	return menu

func _instance_main_panel() -> PauseMainPanel:
	var panel: PauseMainPanel = auto_free(MAIN_PANEL_SCENE.instantiate())
	return panel

func _instance_settings_panel() -> PauseSettingsPanel:
	var panel: PauseSettingsPanel = auto_free(SETTINGS_PANEL_SCENE.instantiate())
	return panel

#region process_mode regression guard
func test_root_process_mode_is_always() -> void:
	var menu := _instance_menu()
	assert_int(menu.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
#endregion

#region main panel button wiring
func test_main_panel_resume_button_emits_signal() -> void:
	var panel := _instance_main_panel()
	add_child(panel)
	await await_idle_frame()
	monitor_signals(panel, false)
	var resume_button := panel.get_node("%ResumeButton") as Button
	resume_button.pressed.emit()
	await assert_signal(panel).is_emitted("resume_pressed")

func test_main_panel_settings_button_emits_signal() -> void:
	var panel := _instance_main_panel()
	add_child(panel)
	await await_idle_frame()
	monitor_signals(panel, false)
	var settings_button := panel.get_node("%SettingsButton") as Button
	settings_button.pressed.emit()
	await assert_signal(panel).is_emitted("settings_pressed")

func test_main_panel_quit_button_emits_signal() -> void:
	var panel := _instance_main_panel()
	add_child(panel)
	await await_idle_frame()
	monitor_signals(panel, false)
	var quit_button := panel.get_node("%QuitButton") as Button
	quit_button.pressed.emit()
	await assert_signal(panel).is_emitted("quit_pressed")
#endregion

#region settings panel button wiring
func test_settings_panel_back_button_emits_signal() -> void:
	var panel := _instance_settings_panel()
	add_child(panel)
	await await_idle_frame()
	monitor_signals(panel, false)
	var back_button := panel.get_node("%BackButton") as Button
	back_button.pressed.emit()
	await assert_signal(panel).is_emitted("back_pressed")
#endregion

#region gamepad focus guard
func test_main_panel_grabs_focus_when_opened() -> void:
	var menu := _instance_menu()
	add_child(menu)
	await await_idle_frame()
	PauseMonitor.pause()
	await await_idle_frame()
	await await_idle_frame()
	var resume_button := menu.main_panel.get_node("%ResumeButton") as Button
	assert_bool(resume_button.has_focus()).is_true()
	PauseMonitor.unpause()
	await await_idle_frame()
#endregion

#region pause synchronization
func test_pause_monitor_paused_opens_main_panel() -> void:
	var menu := _instance_menu()
	add_child(menu)
	await await_idle_frame()
	PauseMonitor.pause()
	await await_idle_frame()
	assert_bool(get_tree().paused).is_true()
	assert_bool(menu.visible).is_true()
	assert_bool(menu.main_panel.visible).is_true()
	PauseMonitor.unpause()
	await await_idle_frame()

func test_pause_monitor_unpaused_closes_menu() -> void:
	var menu := _instance_menu()
	add_child(menu)
	await await_idle_frame()
	PauseMonitor.pause()
	await await_idle_frame()
	PauseMonitor.unpause()
	await await_idle_frame()
	assert_bool(get_tree().paused).is_false()
	assert_bool(menu.visible).is_false()

func test_resume_button_unpauses_and_closes() -> void:
	var menu := _instance_menu()
	add_child(menu)
	await await_idle_frame()
	PauseMonitor.pause()
	await await_idle_frame()
	menu.main_panel.resume_pressed.emit()
	await await_idle_frame()
	assert_bool(get_tree().paused).is_false()
	assert_bool(menu.visible).is_false()
#endregion

func after_test() -> void:
	if get_tree().paused:
		get_tree().paused = false
