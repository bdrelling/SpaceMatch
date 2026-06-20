extends PanelState

func enter(_previous_state_name: StringName) -> void:
	pause_menu.visible = true
	pause_menu.backdrop.visible = true
	pause_menu.main_panel.visible = false
	pause_menu.settings_panel.visible = true
	pause_menu.settings_panel.back_pressed.connect(_on_back)
	pause_menu.settings_panel.grab_initial_focus()

func exit() -> void:
	pause_menu.settings_panel.back_pressed.disconnect(_on_back)

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputAction.PAUSE) or event.is_action_pressed(&"ui_cancel"):
		pause_menu.get_viewport().set_input_as_handled()
		_open_main()

func _on_back() -> void:
	_open_main()
