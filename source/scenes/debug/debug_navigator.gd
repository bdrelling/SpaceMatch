class_name DebugNavigator
extends Control
## The debug shell: a stack of [DebugView] pages with a header (back + title + Done) over a scrolling body.
## One instance is reused everywhere debug is opened — full-screen from the main menu ([DebugScreen]) and as
## an overlay over a paused match ([Game]). Push drills into a page; back pops; Done (or back at the root)
## emits [signal closed] and the host decides what that means. The app's blue/purple background fills the
## screen full-bleed (past the safe area) with content directly on it, inset to the safe area — no inner box.

## The user left the navigator (Done, or back from the root). The host frees the overlay or returns to the
## menu — the navigator doesn't know which.
signal closed()

const _TITLE_FONT := 44
const _BUTTON_FONT := 32
# The shared menu button language (teal/navy), applied at the root so every page, section header, nav
# row, and dropdown picks it up.
const _THEME_PATH := "res://ui/themes/menu_theme.tres"

# The view the navigator opens on, set by create() before it enters the tree.
var _root: DebugView
var _stack: Array[DebugView] = []
var _back_button: Button
var _title_label: Label
var _action_holder: HBoxContainer
var _scroll: ScrollContainer

## Builds a navigator that opens on [param root].
static func create(root: DebugView) -> DebugNavigator:
	var navigator := DebugNavigator.new()
	navigator._root = root
	return navigator

func _ready() -> void:
	# Stay live even when the game tree is paused (the in-match overlay sits over a paused board).
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = load(_THEME_PATH)
	# Size to the viewport explicitly rather than via anchors: the navigator mounts under a plain Node or a
	# CanvasLayer, where anchor-stretch doesn't reliably give it a rect — and the full-bleed background
	# needs a real rect to fill (its children otherwise collapse to zero while min-sized content still shows).
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_build_chrome()
	if _root != null:
		push(_root)

func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

func _build_chrome() -> void:
	# The app's shared cosmos backdrop, full-bleed — it extends past the safe area, edge to edge. Content
	# below is held inside the safe area; no inner panel box. Covers whatever is behind (menu, paused board).
	var background := Background.create()
	background.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow taps so they don't reach anything behind
	add_child(background)

	# Holds the content inside the safe area while the background above bleeds beyond it.
	var safe_area := SafeAreaContainer.new()
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe_area)

	var margin := MarginContainer.new()
	_set_margins(margin, 40)
	safe_area.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	column.add_child(_build_header())
	column.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	_back_button = Button.new()
	_back_button.text = "‹ Back"
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.add_theme_font_size_override("font_size", _BUTTON_FONT)
	_back_button.pressed.connect(pop)
	row.add_child(_back_button)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", _TITLE_FONT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title_label)

	# Holds the current page's optional action (e.g. Match Rules' "+"), swapped per page in _refresh_header.
	_action_holder = HBoxContainer.new()
	_action_holder.add_theme_constant_override("separation", 8)
	row.add_child(_action_holder)

	var done := Button.new()
	done.text = "Done"
	done.focus_mode = Control.FOCUS_NONE
	done.theme_type_variation = &"PrimaryButton"
	done.add_theme_font_size_override("font_size", _BUTTON_FONT)
	done.pressed.connect(func() -> void: closed.emit())
	row.add_child(done)
	return row

## Drills into [param view]: hides the current page, shows the new one, and reveals the back button.
func push(view: DebugView) -> void:
	view.push_requested.connect(push)
	if not _stack.is_empty():
		var current: DebugView = _stack.back()
		_scroll.remove_child(current)
	_stack.append(view)
	_scroll.add_child(view)
	_refresh_header()

## Steps back one page, freeing the one left. At the root, emits [signal closed] instead.
func pop() -> void:
	if _stack.size() <= 1:
		closed.emit()
		return
	var top: DebugView = _stack.pop_back()
	_scroll.remove_child(top)
	top.queue_free()
	var current: DebugView = _stack.back()
	_scroll.add_child(current)
	_refresh_header()

func _refresh_header() -> void:
	_back_button.visible = _stack.size() > 1
	for child: Node in _action_holder.get_children():
		_action_holder.remove_child(child)
		child.queue_free()
	if _stack.is_empty():
		_title_label.text = "Debug"
		return
	var current: DebugView = _stack.back()
	_title_label.text = current.title()
	var act: Button = current.action()
	if act != null:
		_action_holder.add_child(act)

func _set_margins(container: Control, amount: int) -> void:
	container.add_theme_constant_override("margin_left", amount)
	container.add_theme_constant_override("margin_right", amount)
	container.add_theme_constant_override("margin_top", amount)
	container.add_theme_constant_override("margin_bottom", amount)
