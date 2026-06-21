class_name SettingsScreen
extends Control
## The Settings screen — the panel the [SettingsOverlay] shows over the frozen game when the player
## pauses. Placeholder content for now. Done resumes the game; the overlay's dim also dismisses on a
## tap outside the panel. Opened by pausing, not a page in the pager.

@onready var _done_button: Button = %DoneButton

func _ready() -> void:
	_done_button.pressed.connect(PauseMonitor.unpause)
