class_name SettingsScreen
extends Control
## The Settings screen — the panel the [SettingsOverlay] shows over the frozen game when the player
## pauses. Done resumes the game; the overlay's dim also dismisses on a tap outside the panel. Restart
## and Quit are owned by [Game] (they touch the session and scene), so this screen just emits them and
## lets the shell act. Opened by pausing, not a page in the pager.

## The player asked to restart the current game from the Settings panel.
signal restart_pressed()
## The player asked to quit to the main menu from the Settings panel.
signal quit_pressed()

@onready var _done_button: Button = %DoneButton
@onready var _restart_button: Button = %RestartButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	_done_button.pressed.connect(PauseMonitor.unpause)
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_quit_button.pressed.connect(func() -> void: quit_pressed.emit())
