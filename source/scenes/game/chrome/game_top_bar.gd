class_name GameTopBar
extends Control
## The game's top bar: the active stage's title and status on the left, its [MinigameAction] buttons
## and a settings cog on the right. A proper docked bar, not text floating over the board. Its
## [member Background] fills the whole bar — bled up under the top safe-area inset and out to the screen
## sides — while the title/actions/cog row is held inside the safe area by [method _apply_safe_area].

## The cog was tapped — the shell pages to Settings.
signal settings_pressed()

## Bar height below the top safe-area inset, in the portrait design space.
const _CONTENT_HEIGHT: float = 132.0
## Clear space kept between the bar content and the safe-area edge.
const _EDGE_PADDING: float = 24.0

@onready var _content: HBoxContainer = $Content
@onready var _title: Label = %Title
@onready var _status: Label = %Status
@onready var _actions: HBoxContainer = %Actions
@onready var _settings: Button = %Settings

var _insets := SafeArea.Insets.empty()

func _ready() -> void:
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

func set_title(text: String) -> void:
	_title.text = text

func set_status(text: String) -> void:
	_status.text = text
	_status.visible = text != ""

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
