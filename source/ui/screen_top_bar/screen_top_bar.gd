class_name ScreenTopBar
extends Control
## A reusable top bar for standalone screens — the ones presented in a [ScreenContainer] rather than the
## [Game] shell. A leading back button, a centered title, and an optional trailing primary action. It
## owns no navigation: it emits [signal back_pressed] / [signal action_pressed] and the host screen
## decides where those go. Set the labels with [method configure].

## The leading (back) button was tapped.
signal back_pressed
## The trailing primary action was tapped. Only fires when an action label is set (see [method configure]).
signal action_pressed

@onready var _back_button: Button = %Back
@onready var _title_label: Label = %Title
@onready var _action_button: Button = %Action

func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	_action_button.pressed.connect(func() -> void: action_pressed.emit())

## Sets the title and the trailing action's label. An empty [param action_text] hides the action button
## (a back-only bar). Call once the bar is in the tree — e.g. from the host screen's [code]_ready[/code].
func configure(title: String, action_text: String = "") -> void:
	_title_label.text = title
	_action_button.text = action_text
	_action_button.visible = not action_text.is_empty()
