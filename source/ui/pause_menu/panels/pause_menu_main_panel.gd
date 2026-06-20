class_name PauseMainPanel
extends PanelContainer

signal resume_pressed
signal settings_pressed
signal quit_pressed

@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	_resume_button.pressed.connect(resume_pressed.emit)
	_settings_button.pressed.connect(settings_pressed.emit)
	_quit_button.pressed.connect(quit_pressed.emit)

func grab_initial_focus() -> void:
	_resume_button.grab_focus.call_deferred()
