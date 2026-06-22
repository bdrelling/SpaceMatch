class_name GameTopBar
extends Control
## The game's top bar: a leading back button on the left, the player's scrap counter and a settings cog
## on the right — no title, since each stage now carries its own chrome. The bar itself is transparent
## (the shell's gradient shows through); it sits inside the shell's SafeAreaContainer, which holds its
## button row clear of the device notch, and [method _apply_safe_area] only insets that row from the bar edges.

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
## The scrap tile kind, reused as the counter's glyph so the nav-bar currency matches the board.
const _SCRAP_TILE_KIND: int = 4
## Side length of the scrap counter's tile glyph.
const _SCRAP_ICON_PX: float = 48.0

@onready var _content: HBoxContainer = $Content
@onready var _leading: Button = %Leading
@onready var _actions: HBoxContainer = %Actions
@onready var _settings: Button = %Settings

var _insets := SafeArea.Insets.empty()
var _scrap_value: Label

func _ready() -> void:
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_leading.pressed.connect(func() -> void: leading_pressed.emit())
	_build_scrap_counter()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

## Sets the nav-bar scrap counter to [param amount].
func set_scrap(amount: int) -> void:
	if _scrap_value != null:
		_scrap_value.text = str(amount)

# Builds the scrap counter — the scrap tile glyph beside its count — and seats it just left of the cog.
# Built in code (like the portrait readouts) so it reuses [TileIcon] rather than re-authoring the glyph.
func _build_scrap_counter() -> void:
	var chip := HBoxContainer.new()
	chip.name = "Scrap"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_constant_override("separation", 10)

	var icon := TileIcon.new()
	icon.kind = _SCRAP_TILE_KIND
	icon.custom_minimum_size = Vector2(_SCRAP_ICON_PX, _SCRAP_ICON_PX)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)

	_scrap_value = Label.new()
	_scrap_value.text = "0"
	_scrap_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scrap_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrap_value.add_theme_font_size_override("font_size", 40)
	chip.add_child(_scrap_value)

	_content.add_child(chip)
	# Reorder to sit just before the settings cog (the rightmost item).
	_content.move_child(chip, _settings.get_index())

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

# Sizes the bar to its content and insets that content from the bar edges. The bar lives inside the
# shell's SafeAreaContainer, which already holds it clear of the device notch, so it adds no top inset
# of its own; the background, anchored to the bar's full rect, bleeds out to the sides.
func _apply_safe_area() -> void:
	_insets = DeviceUtils.get_safe_area(get_viewport()).insets
	custom_minimum_size.y = _CONTENT_HEIGHT
	_content.offset_left = _insets.leading + _EDGE_PADDING
	_content.offset_top = _EDGE_PADDING
	_content.offset_right = -(_insets.trailing + _EDGE_PADDING)
	_content.offset_bottom = -_EDGE_PADDING
