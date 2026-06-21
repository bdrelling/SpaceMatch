class_name GameTopBar
extends Control
## The game's top bar: a leading back button on the left and a settings cog on the right — no title,
## since each stage now carries its own chrome. The bar itself is transparent (the shell's gradient
## shows through); its button row is held inside the device safe area by [method _apply_safe_area].

## The cog was tapped — the shell opens the Settings overlay.
signal settings_pressed()
## The leading button (a back arrow) was tapped — the shell steps back from a sub-screen to the primary
## stage. Shown only on sub-screens; the primary stage hides it (see [method hide_leading]).
signal leading_pressed()

## The leading button's back-arrow glyph, shown via [method show_leading] on a sub-screen.
const LEADING_BACK: String = "←"

## Bar height below the top safe-area inset, in the portrait design space.
const _CONTENT_HEIGHT: float = 132.0
## Clear space kept between the bar content and the safe-area edge.
const _EDGE_PADDING: float = 24.0

@onready var _content: HBoxContainer = $Content
@onready var _leading: Button = %Leading
@onready var _actions: HBoxContainer = %Actions
@onready var _settings: Button = %Settings

var _insets := SafeArea.Insets.empty()

func _ready() -> void:
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_leading.pressed.connect(func() -> void: leading_pressed.emit())
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

## Shows the leading button with [param glyph] (a sub-screen's back arrow).
func show_leading(glyph: String) -> void:
	_leading.text = glyph
	_leading.visible = true

## Hides the leading button — the primary stage has no top-left button (it drills from its own HUD).
func hide_leading() -> void:
	_leading.visible = false

## Rebuilds the right-side action buttons from the active stage's declared [param actions].
func set_actions(actions: Array[MinigameAction]) -> void:
	for child: Node in _actions.get_children():
		child.queue_free()
	for action: MinigameAction in actions:
		var button := Button.new()
		button.text = action.label
		button.focus_mode = Control.FOCUS_NONE
		if action.on_pressed.is_valid():
			button.pressed.connect(action.on_pressed)
		_actions.add_child(button)

# Sizes the bar to clear the top inset and insets its content to the safe area; the background, anchored
# to the bar's full rect, keeps bleeding under the notch and out to the sides.
func _apply_safe_area() -> void:
	_insets = DeviceUtils.get_safe_area(get_viewport()).insets
	custom_minimum_size.y = _insets.top + _CONTENT_HEIGHT
	_content.offset_left = _insets.leading + _EDGE_PADDING
	_content.offset_top = _insets.top + _EDGE_PADDING
	_content.offset_right = -(_insets.trailing + _EDGE_PADDING)
	_content.offset_bottom = -_EDGE_PADDING
