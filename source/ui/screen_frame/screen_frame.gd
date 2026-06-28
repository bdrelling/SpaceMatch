class_name ScreenFrame
extends Control
## The standard on-screen frame: the app [Background] and device safe area, a [NavigationBar], and a
## content slot below it. Composite screens (the loadout, the encounter, debug, …) instance this and drop
## a raw feature scene — e.g. [code]match.tscn[/code] — into the content slot, so feature scenes stay
## bar-less and the frame is authored once.
##
## Mount content authored in the scene under the [code]Content[/code] node, or at runtime with
## [method set_content]. Configure the bar with [method configure_bar], or drop it entirely with
## [method hide_bar] for a frame that's just background + safe area.

#region Signals

## The bar's leading (back) button was tapped.
signal back_pressed
## The bar's trailing action was tapped (only fires when an action label is set).
signal action_pressed
## The bar's settings cog was tapped (only fires when the cog is shown — see [method show_settings]).
signal settings_pressed

#endregion

#region Properties

@onready var _navigation_bar: NavigationBar = %NavigationBar
@onready var _content: Control = %Content

#endregion

#region Lifecycle

func _ready() -> void:
	_navigation_bar.back_pressed.connect(func() -> void: back_pressed.emit())
	_navigation_bar.action_pressed.connect(func() -> void: action_pressed.emit())
	_navigation_bar.settings_pressed.connect(func() -> void: settings_pressed.emit())

#endregion

#region Methods

## Sets the bar's title and trailing action label (empty hides just the action). See [NavigationBar].
func configure_bar(title: String, action_text: String = "") -> void:
	_navigation_bar.configure(title, action_text)

## Hides the whole bar — for a frame that wants the background and safe area but no bar.
func hide_bar() -> void:
	_navigation_bar.visible = false

## Shows or hides the bar's settings cog (off by default). Shown screens get [signal settings_pressed].
func show_settings(shown: bool) -> void:
	_navigation_bar.show_settings(shown)

## Shows or hides the bar's currency (scrap) readout (off by default). Set its value with [method set_scrap].
func show_scrap(shown: bool) -> void:
	_navigation_bar.show_scrap(shown)

## Sets the bar's currency (scrap) readout value. Only visible once [method show_scrap] is on.
func set_scrap(amount: int) -> void:
	_navigation_bar.set_scrap(amount)

## Mounts [param content] in the slot below the bar, replacing anything already there.
func set_content(content: Control) -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if content != null:
		_content.add_child(content)

#endregion
