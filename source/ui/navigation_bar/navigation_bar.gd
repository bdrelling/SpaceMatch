class_name NavigationBar
extends Control
## A reusable navigation bar for screens framed by a [ScreenFrame]. A leading back button, a centered
## title, and an optional trailing primary action. It owns no navigation: it emits [signal back_pressed] /
## [signal action_pressed] and the host screen decides where those go. Set the labels with [method configure].

## The leading (back) button was tapped.
signal back_pressed
## The trailing primary action was tapped. Only fires when an action label is set (see [method configure]).
signal action_pressed
## The trailing settings cog was tapped. Only fires when the cog is shown (see [method show_settings]).
signal settings_pressed

@onready var _back_button: Button = %Back
@onready var _title_label: Label = %Title
@onready var _action_button: Button = %Action
@onready var _scrap: HBoxContainer = %Scrap
@onready var _scrap_value: Label = %ScrapValue
@onready var _settings_button: Button = %Settings

func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	_action_button.pressed.connect(func() -> void: action_pressed.emit())
	_settings_button.pressed.connect(func() -> void: settings_pressed.emit())

## Sets the title and the trailing action's label. An empty [param action_text] hides the action button
## (a back-only bar). Call once the bar is in the tree — e.g. from the host screen's [code]_ready[/code].
func configure(title: String, action_text: String = "") -> void:
	_title_label.text = title
	_action_button.text = action_text
	_action_button.visible = not action_text.is_empty()

## Shows or hides the trailing settings cog — the bar's optional extra affordance (off by default, so a
## plain back/title/action bar stays clean). Shown screens get [signal settings_pressed].
func show_settings(shown: bool) -> void:
	_settings_button.visible = shown

## Shows or hides the trailing currency (scrap) readout — off by default. The encounter shows it so the
## player's scrap balance is visible over the board; set the value with [method set_scrap].
func show_scrap(shown: bool) -> void:
	_scrap.visible = shown

## Sets the currency (scrap) readout's value. Only visible once [method show_scrap] is on.
func set_scrap(amount: int) -> void:
	_scrap_value.text = str(amount)
