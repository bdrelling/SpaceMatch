extends PanelState

func enter(_previous_state_name: StringName) -> void:
	pause_menu.visible = true
	pause_menu.backdrop.visible = true
	pause_menu.main_panel.visible = true
	pause_menu.settings_panel.visible = false
	pause_menu.main_panel.resume_pressed.connect(_on_resume)
	pause_menu.main_panel.settings_pressed.connect(_on_settings)
	pause_menu.main_panel.quit_pressed.connect(_on_quit)
	pause_menu.main_panel.grab_initial_focus()

func exit() -> void:
	pause_menu.main_panel.resume_pressed.disconnect(_on_resume)
	pause_menu.main_panel.settings_pressed.disconnect(_on_settings)
	pause_menu.main_panel.quit_pressed.disconnect(_on_quit)

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputAction.PAUSE) or event.is_action_pressed(&"ui_cancel"):
		pause_menu.get_viewport().set_input_as_handled()
		PauseMonitor.unpause()

func _on_resume() -> void:
	PauseMonitor.unpause()

func _on_settings() -> void:
	transitioned.emit(&"SettingsPanelState")

func _on_quit() -> void:
	get_tree().quit()
