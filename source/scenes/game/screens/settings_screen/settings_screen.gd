class_name SettingsScreen
extends Control
## The Settings screen — the full-screen menu the [SettingsOverlay] shows over the frozen game when the
## player pauses. Resume resumes the game (touch has no ESC/joypad, so its button is the way out). Restart
## and Quit are owned by [Game] (they touch the session and scene), so this screen just emits them and
## lets the shell act. Opened by pausing, not a page in the pager.

## The player asked to restart the current game from the Settings panel.
signal restart_pressed()
## The player asked to quit to the main menu from the Settings panel.
signal quit_pressed()
## The player asked to open the Debug tuning panel over the (still paused) game. [Game] shows it.
signal debug_pressed()

@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _debug_button: Button = %DebugButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	_resume_button.pressed.connect(PauseMonitor.unpause)
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_debug_button.pressed.connect(func() -> void: debug_pressed.emit())
	_quit_button.pressed.connect(func() -> void: quit_pressed.emit())
