class_name GamePager
extends Control
## Shows one [GameScreen] at a time and steps between them (left/right). The host adds screens —
## already bound to the session — and the pager owns only which one is visible.

signal page_changed(index: int)

## Minimum horizontal drag (pixels) that counts as a swipe rather than a tap.
const _SWIPE_THRESHOLD := 60.0
## Accumulated horizontal trackpad pan (pixels) that pages — bigger than a drag so a stray
## two-finger scroll doesn't flip pages.
const _PAN_THRESHOLD := 80.0

var screens: Array[GameScreen] = []
var _index: int = 0
var _swipe_origin_x: float = 0.0
var _swiping := false
var _pan_x: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Adopt any screens authored as children in the scene — how the game composes its pages.
	# Programmatic hosts and tests add their own with add_screen() on an empty pager instead.
	for child: Node in get_children():
		if child is GameScreen:
			_register(child as GameScreen)

## Mounts [param screen] as a full-rect page; the first one added is the one shown.
func add_screen(screen: GameScreen) -> void:
	add_child(screen)
	_register(screen)

# Tracks a screen as a page: full-rect, and visible only if it's the first one registered.
func _register(screen: GameScreen) -> void:
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.visible = screens.is_empty()
	screens.append(screen)

## Frees every screen and resets to empty — the host re-adds screens on restart.
func clear() -> void:
	for screen: GameScreen in screens:
		screen.queue_free()
	screens.clear()
	_index = 0

func show_index(index: int) -> void:
	if screens.is_empty():
		return
	_index = wrapi(index, 0, screens.size())
	for i in screens.size():
		screens[i].visible = i == _index
	page_changed.emit(_index)

func next() -> void:
	show_index(_index + 1)

func previous() -> void:
	show_index(_index - 1)

func _unhandled_input(event: InputEvent) -> void:
	if screens.size() < 2:
		return
	# No keyboard paging: left/right stay free for a minigame's own controls (e.g. moving a
	# falling piece). Pages turn only on a swipe, trackpad pan, or horizontal wheel.
	_handle_swipe(event)

# Pages from a horizontal gesture: a touch (mobile) or left-drag (desktop) past the swipe threshold,
# a trackpad two-finger pan past the pan threshold, or a horizontal scroll-wheel tick. Events that
# land on a tab or button are consumed there and never reach this unhandled pass.
func _handle_swipe(event: InputEvent) -> void:
	var pan := event as InputEventPanGesture
	if pan != null:
		_handle_pan(pan)
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		_track_swipe(touch.pressed, touch.position.x)
		return
	var click := event as InputEventMouseButton
	if click == null:
		return
	if click.button_index == MOUSE_BUTTON_WHEEL_LEFT and click.pressed:
		previous()
	elif click.button_index == MOUSE_BUTTON_WHEEL_RIGHT and click.pressed:
		next()
	elif click.button_index == MOUSE_BUTTON_LEFT:
		_track_swipe(click.pressed, click.position.x)

# Trackpad two-finger horizontal pan. Deltas arrive as a stream, so accumulate until they cross the
# threshold, then page and reset; mostly-vertical pans (scrolling) are ignored.
func _handle_pan(pan: InputEventPanGesture) -> void:
	if absf(pan.delta.x) <= absf(pan.delta.y):
		return
	_pan_x += pan.delta.x
	if absf(_pan_x) < _PAN_THRESHOLD:
		return
	if _pan_x < 0.0:
		next()
	else:
		previous()
	_pan_x = 0.0

func _track_swipe(pressed: bool, x: float) -> void:
	if pressed:
		_swipe_origin_x = x
		_swiping = true
	elif _swiping:
		_swiping = false
		_resolve_swipe(x - _swipe_origin_x)

func _resolve_swipe(delta_x: float) -> void:
	if absf(delta_x) < _SWIPE_THRESHOLD:
		return
	if delta_x < 0.0:
		next()
	else:
		previous()
