class_name MatchAction
extends RefCounted
## A labelled button (a label plus an on-press [Callable]) the match exposes via [method MatchGame.actions]
## — its Rules button and the like. The host owns the button widget; the match supplies the label and what
## a press does.

var label: String
var on_pressed: Callable

func _init(action_label: String = "", pressed: Callable = Callable()) -> void:
	label = action_label
	on_pressed = pressed
