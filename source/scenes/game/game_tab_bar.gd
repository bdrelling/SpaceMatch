class_name GameTabBar
extends Control
## The bottom strip of stage tabs — one toggle button per minigame, sharing a [ButtonGroup] so exactly
## one is held down. Its [member Background] bleeds out to the screen sides and down into the bottom
## safe-area inset (one unbroken color from the buttons to the screen edge), while the button row insets
## by the safe area plus an edge gap so the tabs never sit flush against the corners. Settings is not a
## tab — it lives behind the top-bar cog — so the bar carries only the playable stages.

signal tab_selected(index: int)

## Button-row height above the bottom safe-area inset, in the portrait design space.
const _CONTENT_HEIGHT: float = 116.0
## Clear space kept between the buttons and the safe-area edge.
const _EDGE_PADDING: float = 16.0

@onready var _buttons_row: HBoxContainer = $Buttons

var _buttons: Array[Button] = []
var _insets := SafeArea.Insets.empty()

func _ready() -> void:
	# Adopt the tabs authored in the scene — each emits its page index when tapped.
	for child: Node in _buttons_row.get_children():
		if child is Button:
			var index := _buttons.size()
			(child as Button).pressed.connect(func() -> void: tab_selected.emit(index))
			_buttons.append(child as Button)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

## The authored tab buttons, in order — exposed so the shell (and tests) can inspect them.
func tab_buttons() -> Array[Button]:
	return _buttons

## Labels the authored tabs in order from [param titles] — the pages' own titles, so a stage's name
## lives only on its page and the tab mirrors it (no duplicated strings to drift).
func set_labels(titles: Array[String]) -> void:
	for index: int in mini(titles.size(), _buttons.size()):
		_buttons[index].text = titles[index]

## Highlights the tab at [param index] (and only that one) without re-emitting [signal tab_selected];
## an out-of-range index — e.g. when the cog opens Settings — clears every tab.
func set_active(index: int) -> void:
	for i: int in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == index)

# Sizes the bar to clear the bottom inset and insets the button row to the safe area; the background,
# anchored to the bar's full rect, keeps bleeding to the sides and down to the screen edge.
func _apply_safe_area() -> void:
	_insets = DeviceUtils.get_safe_area(get_viewport()).insets
	custom_minimum_size.y = _insets.bottom + _CONTENT_HEIGHT
	_buttons_row.offset_left = _insets.leading + _EDGE_PADDING
	_buttons_row.offset_top = _EDGE_PADDING
	_buttons_row.offset_right = -(_insets.trailing + _EDGE_PADDING)
	_buttons_row.offset_bottom = -(_insets.bottom + _EDGE_PADDING)
