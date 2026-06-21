class_name MinigameAction
extends RefCounted
## A labelled button the [Game] top bar mounts for the active [Minigame] — its reset, mode toggle, and
## the like. The shell owns the button widget; the stage supplies the label and what a press does.

var label: String
var on_pressed: Callable

func _init(action_label: String = "", pressed: Callable = Callable()) -> void:
	label = action_label
	on_pressed = pressed
