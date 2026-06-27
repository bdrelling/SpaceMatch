class_name ScreenFrame
extends Control
## The standard on-screen frame: the app [Background] and device safe area, a [ScreenTopBar], and a
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

#endregion

#region Properties

@onready var _top_bar: ScreenTopBar = %TopBar
@onready var _content: Control = %Content

#endregion

#region Lifecycle

func _ready() -> void:
	_top_bar.back_pressed.connect(func() -> void: back_pressed.emit())
	_top_bar.action_pressed.connect(func() -> void: action_pressed.emit())

#endregion

#region Methods

## Sets the bar's title and trailing action label (empty hides just the action). See [ScreenTopBar].
func configure_bar(title: String, action_text: String = "") -> void:
	_top_bar.configure(title, action_text)

## Hides the whole bar — for a frame that wants the background and safe area but no bar.
func hide_bar() -> void:
	_top_bar.visible = false

## Mounts [param content] in the slot below the bar, replacing anything already there.
func set_content(content: Control) -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if content != null:
		_content.add_child(content)

#endregion
