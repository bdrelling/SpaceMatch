class_name DebugNavigator
extends Control
## The debug shell: a stack of [DebugView] pages with a header (back + title + Done) over a scrolling body.
## One instance is reused everywhere debug is opened — full-screen from the main menu ([DebugScreen]) and as
## an overlay over a paused match ([Game]). Push drills into a page; back pops; Done (or back at the root)
## emits [signal closed] and the host decides what that means. The app's blue/purple background fills the
## screen full-bleed (past the safe area) with content directly on it, inset to the safe area — no inner box.
## The shell is authored in [code]debug_navigator.tscn[/code] (so it renders in the editor); this script wires
## the nodes and owns the page stack.

## The user left the navigator (Done, or back from the root). The host frees the overlay or returns to the
## menu — the navigator doesn't know which.
signal closed()

# The authored shell, instanced by create() for code-built hosts.
const _SCENE_PATH := "res://scenes/debug/debug_navigator.tscn"

# The view the navigator opens on, set by create() before it enters the tree.
var _root: DebugView
var _stack: Array[DebugView] = []

@onready var _back_button: Button = %Back
@onready var _title_label: Label = %Title
@onready var _action_holder: HBoxContainer = %ActionHolder
@onready var _scroll: ScrollContainer = %Scroll
@onready var _done_button: Button = %Done

## Builds a navigator that opens on [param root].
static func create(root: DebugView) -> DebugNavigator:
	var scene: PackedScene = load(_SCENE_PATH)
	var navigator: DebugNavigator = scene.instantiate()
	navigator._root = root
	return navigator

func _ready() -> void:
	# Stay live even when the game tree is paused (the in-match overlay sits over a paused board).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Size to the viewport explicitly rather than via anchors: the navigator mounts under a plain Node or a
	# CanvasLayer, where anchor-stretch doesn't reliably give it a rectangle — and the full-bleed background
	# needs a real rectangle to fill (its children otherwise collapse to zero while min-sized content still shows).
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_back_button.pressed.connect(pop)
	_done_button.pressed.connect(func() -> void: closed.emit())
	if _root != null:
		push(_root)

func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

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
