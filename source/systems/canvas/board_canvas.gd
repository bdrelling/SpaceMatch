class_name BoardCanvas
extends Control
## A backing container that frames a content node: it centers the node inside this control with
## margin and fits it to the rect. With [member interactive] on it also lets the player pinch/scroll
## to zoom and two-finger/middle-drag to pan. Fully game-agnostic: hand it any [Node2D] and its
## unscaled pixel size — grid, pachinko, anything — and it owns the framing so every screen that
## hosts a board looks and feels the same.
##
## The content draws from its own local origin (0, 0); this canvas applies the centering, fit scale,
## zoom, and pan as the content's [member Node2D.transform], so hit-testing through
## [method Node2D.to_local] stays correct under any zoom. Pointer events the canvas doesn't claim for
## zoom/pan are forwarded to [member input_handler], so the host's own gestures are untouched and the
## canvas never names a gesture type.
##
## Pan/zoom is an iOS-style committed-plus-overscroll split: the committed transform is always fitted
## and clamped inside [member padding] (plus the safe-area inset overlapping this control), and the
## gesture drives it directly — so when zoomed in, the board pans freely inside the widened band with
## no spring. A drag past the band (or any drag at fit, where the band is zero-width) only moves a
## separate overscroll layer with diminishing resistance, which eases back to the committed framing
## once the gesture stops. [member pan_bounce] / [member zoom_bounce] toggle that give per axis.

## When false (the default), the board is locked to its fit-and-centered framing: no pan, no zoom —
## only forwarded gestures pass through. Turn on once a screen wants the player to move the camera.
@export var interactive: bool = false

## Clear space (px, in the 1920x1080 design space) kept between the board and this control's edges,
## added on top of any safe-area inset that overlaps this control.
@export var padding: float = 20.0
## Zoom range as multiples of the fit-to-rect scale. 1.0 = exactly fitted; 3.0 = three times in.
@export var min_zoom: float = 1.0
@export var max_zoom: float = 3.0
## Multiplier applied per scroll-wheel notch.
@export var wheel_zoom_step: float = 1.1
## Board pixels moved per unit of trackpad pan-gesture delta. Raise it if two-finger panning drags.
@export var pan_gesture_speed: float = 16.0

## When true, the board can be tugged past its pan band with diminishing resistance and springs back
## once the gesture stops. At fit the band is zero-width, so every drag is a tug that springs back;
## zoomed in, only drags past the widened band tug.
@export var pan_bounce: bool = true
## When true, zoom can be pinched past [member min_zoom] / [member max_zoom] with resistance and
## springs back into range once the gesture stops.
@export var zoom_bounce: bool = true
## How far (px) past the pan band the tug asymptotes to. Larger feels looser.
@export var max_overscroll: float = 80.0
## How far (in zoom-multiplier units) past the zoom range a pinch can stretch before springing back.
@export var zoom_overscroll: float = 0.3
## Spring-back speed for the overscroll ease; higher snaps back faster.
@export var settle_speed: float = 14.0

## The framed content node — whatever the host injected via [method set_board], drawn from its own
## (0, 0) origin. Null until a board is set.
var board: Node2D

## Optional handler for pointer events the canvas doesn't claim for zoom/pan. It receives the
## [InputEvent] and returns true when it consumed it; the host wires its own gesture layer here (e.g.
## a recognizer's [code]handle_event[/code]) so board gestures work regardless of how much UI chrome
## sits between the board and the viewport's unhandled-input pass.
var input_handler: Callable

var _content_size: Vector2
var _fit_scale: float = 1.0
# Committed view: always within [min_zoom, max_zoom] and the pan band. The gesture writes these
# directly so panning is exact and never fights a spring.
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
# Overscroll layer: display-only give past the committed view, decayed to zero when the gesture idles.
# _pan_over is px; _zoom_over is a fractional scale applied about the board's center.
var _pan_over: Vector2 = Vector2.ZERO
var _zoom_over: float = 0.0
var _panning: bool = false
# Per-edge clear space: padding plus the safe-area inset overlapping this control. _min is left/top,
# _max is right/bottom; centering absorbs the asymmetry so the pan band stays symmetric.
var _margin_min: Vector2 = Vector2.ZERO
var _margin_max: Vector2 = Vector2.ZERO
# Seconds since the last pan / zoom input; the overscroll eases back only after a brief idle so it
# doesn't fight an in-progress gesture.
var _pan_idle: float = 1.0
var _zoom_idle: float = 1.0
# Armed while a touch owns the pointer, so the left-button mouse events the OS emulates from that touch
# are dropped instead of firing the board a second time. See [method _is_emulated_pointer].
var _touch_guard: bool = false

const _GESTURE_IDLE_HOLD: float = 0.08
const _SETTLE_EPSILON: float = 0.5
const _ZOOM_EPSILON: float = 0.0005

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(false)
	resized.connect(_reframe)

## Mounts [param content] (drawn from its origin, [param content_size] px unscaled) as the zoom/pan
## target and frames it. Replaces any previously mounted board.
func set_board(content: Node2D, content_size: Vector2) -> void:
	if board != null and board.get_parent() == self:
		remove_child(board)
	board = content
	_content_size = content_size
	_zoom = 1.0
	_pan = Vector2.ZERO
	_pan_over = Vector2.ZERO
	_zoom_over = 0.0
	add_child(board)
	_reframe()

## Re-centers and re-fits without changing zoom — call when the board regenerates at the same size.
func recenter() -> void:
	_pan = Vector2.ZERO
	_pan_over = Vector2.ZERO
	_zoom_over = 0.0
	_zoom = clampf(_zoom, min_zoom, max_zoom)
	_reframe()

func _gui_input(event: InputEvent) -> void:
	if board == null:
		return
	# On a touch device the OS emits the raw touch and then a left-button mouse it emulates from it —
	# and that emulated press can land *after* the finger lifts. Drop the emulated pair here, once, so
	# every handler below sees each physical tap a single time. Without this a press-driven toggle (e.g.
	# the placement tray's selection) fires twice per tap and nets back to nothing.
	if _is_emulated_pointer(event):
		accept_event()
		return
	if interactive and _handle_view_gesture(event):
		accept_event()
		return
	# Anything not claimed for zoom/pan is a board gesture — hand it to the host's handler here rather
	# than waiting for _unhandled_input, which the chrome above the board can swallow before it arrives.
	# _gui_input positions are local to this control, but the host resolves cells against the board's
	# GLOBAL transform (e.g. Node2D.to_local), so forward a global-space copy — otherwise every tap is
	# offset by the chrome above the canvas and lands on the wrong cell.
	if input_handler.is_valid() and input_handler.call(event.xformed_by(get_global_transform())):
		accept_event()

# True when [param event] is a left-button mouse event the OS emulated from a touch, which should be
# dropped so the touch it mirrors isn't acted on twice. A touch press arms the guard and keeps it armed
# through the finger lift (the emulated press can arrive after release); the emulated release disarms it.
# Mouse wheel/middle and genuine mouse input (no touch in flight) pass through untouched, so desktop is
# unaffected.
func _is_emulated_pointer(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_touch_guard = true
		return false
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index != MOUSE_BUTTON_LEFT or not _touch_guard:
			return false
		if not button.pressed:
			_touch_guard = false
		return true
	if event is InputEventMouseMotion:
		return _touch_guard
	return false

# Pinch/scroll zoom and two-finger/middle-drag pan — the view manipulations the
# canvas owns. Returns true when it consumed the event.
func _handle_view_gesture(event: InputEvent) -> bool:
	var magnify := event as InputEventMagnifyGesture
	if magnify != null:
		_apply_zoom(_zoom * magnify.factor, magnify.position)
		_zoom_idle = 0.0
		_wake()
		return true
	var pan := event as InputEventPanGesture
	if pan != null:
		_apply_pan_delta(-pan.delta * pan_gesture_speed)
		_pan_idle = 0.0
		_wake()
		return true
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_apply_zoom(_zoom * wheel_zoom_step, button.position)
			_zoom_idle = 0.0
			_wake()
			return true
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_apply_zoom(_zoom / wheel_zoom_step, button.position)
			_zoom_idle = 0.0
			_wake()
			return true
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = button.pressed
			if not _panning:
				_pan_idle = 0.0
				_wake()
			return true
		return false
	var motion := event as InputEventMouseMotion
	if motion != null and _panning:
		_apply_pan_delta(motion.relative)
		_pan_idle = 0.0
		return true
	return false

# Drives the committed pan straight from the gesture (clamped to the band) and routes only the
# leftover past the band into the resisted overscroll layer, so in-band panning is exact and stable.
func _apply_pan_delta(delta_px: Vector2) -> void:
	var limit: Vector2 = _pan_limit()
	var raw: Vector2 = _pan + _pan_over + delta_px
	_pan = raw.clamp(-limit, limit)
	if pan_bounce:
		_pan_over = _resisted_excess(raw, limit)
	else:
		_pan_over = Vector2.ZERO
	_apply_transform()

# Zooms toward [param focus] (in this control's local space) so the board point under the cursor
# stays put. The committed zoom is focus-preserving and in-range; any excess becomes a decaying
# overscroll stretch about the board center.
func _apply_zoom(target_zoom: float, focus: Vector2) -> void:
	var base_scale_old: float = _fit_scale * _zoom
	var board_point: Vector2 = (focus - (_centered_origin(base_scale_old) + _pan)) / base_scale_old
	_zoom = clampf(target_zoom, min_zoom, max_zoom)
	var base_scale_new: float = _fit_scale * _zoom
	var limit: Vector2 = _pan_limit()
	_pan = (focus - board_point * base_scale_new - _centered_origin(base_scale_new)).clamp(-limit, limit)
	if zoom_bounce and _zoom > 0.0:
		_zoom_over = _rubber_scalar(target_zoom, min_zoom, max_zoom, zoom_overscroll) / _zoom - 1.0
	else:
		_zoom_over = 0.0
	_apply_transform()

# Eases the overscroll layer back to zero once the gesture goes idle; the committed view is untouched,
# so this never fights an active pan. Sleeps when nothing is overscrolled.
func _process(delta: float) -> void:
	if board == null:
		set_process(false)
		return
	if not _panning:
		_pan_idle += delta
	_zoom_idle += delta
	var smoothing: float = 1.0 - exp(-settle_speed * delta)
	var changed: bool = false
	if _zoom_idle >= _GESTURE_IDLE_HOLD and _zoom_over != 0.0:
		_zoom_over = lerpf(_zoom_over, 0.0, smoothing)
		if absf(_zoom_over) < _ZOOM_EPSILON:
			_zoom_over = 0.0
		changed = true
	if not _panning and _pan_idle >= _GESTURE_IDLE_HOLD and _pan_over != Vector2.ZERO:
		_pan_over = _pan_over.lerp(Vector2.ZERO, smoothing)
		if _pan_over.length() < _SETTLE_EPSILON:
			_pan_over = Vector2.ZERO
		changed = true
	if changed:
		_apply_transform()
	if not _panning and _pan_over == Vector2.ZERO and _zoom_over == 0.0:
		set_process(false)

func _wake() -> void:
	set_process(true)

# Re-fits the board to the current rect (minus margins) and re-applies zoom/pan on top.
func _reframe() -> void:
	if board == null or _content_size.x <= 0.0 or _content_size.y <= 0.0:
		return
	_recompute_margins()
	var inner: Vector2 = _inner_size()
	_fit_scale = maxf(minf(inner.x / _content_size.x, inner.y / _content_size.y), 0.01)
	_zoom = clampf(_zoom, min_zoom, max_zoom)
	_pan_over = Vector2.ZERO
	_zoom_over = 0.0
	var limit: Vector2 = _pan_limit()
	_pan = _pan.clamp(-limit, limit)
	_apply_transform()

func _apply_transform() -> void:
	var base_scale: float = _fit_scale * _zoom
	var zoom_factor: float = 1.0 + _zoom_over
	var scale_factor: float = base_scale * zoom_factor
	board.scale = Vector2(scale_factor, scale_factor)
	# Scale the zoom overscroll about the board's center so a bounce doesn't shove it off, then add the
	# committed framing and the pan overscroll.
	var pivot_adjust: Vector2 = _content_size * 0.5 * base_scale * (1.0 - zoom_factor)
	board.position = _centered_origin(base_scale) + _pan + pivot_adjust + _pan_over

# padding + whatever safe-area inset overlaps this control, per edge. Safe area is read in the
# viewport's design space (canvas_items stretch) so it lines up with this control's global rect; it's
# zero on desktop and in the editor.
func _recompute_margins() -> void:
	_margin_min = Vector2(padding, padding)
	_margin_max = Vector2(padding, padding)
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var safe_rect: Rect2 = DeviceUtils.get_safe_area(viewport).rect
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return
	var rect: Rect2 = get_global_rect()
	_margin_min.x += maxf(0.0, safe_rect.position.x - rect.position.x)
	_margin_min.y += maxf(0.0, safe_rect.position.y - rect.position.y)
	_margin_max.x += maxf(0.0, rect.end.x - safe_rect.end.x)
	_margin_max.y += maxf(0.0, rect.end.y - safe_rect.end.y)

func _inner_size() -> Vector2:
	return size - _margin_min - _margin_max

# Top-left that centers the scaled board inside the margined inner rect, offsetting by the asymmetric
# margins so unequal safe insets stay balanced.
func _centered_origin(scale_factor: float) -> Vector2:
	return _margin_min + (_inner_size() - _content_size * scale_factor) * 0.5

# Symmetric pan band: half the board's overhang past the inner rect, per axis, never negative. Zero
# when the board fits, growing with zoom so a zoomed board's edges stop exactly at the margin.
func _pan_limit() -> Vector2:
	var inner: Vector2 = _inner_size()
	var scaled: Vector2 = _content_size * (_fit_scale * _zoom)
	return Vector2(maxf((scaled.x - inner.x) * 0.5, 0.0), maxf((scaled.y - inner.y) * 0.5, 0.0))

# The portion of [param raw] beyond the band, run through diminishing resistance per axis.
func _resisted_excess(raw: Vector2, limit: Vector2) -> Vector2:
	var clamped: Vector2 = raw.clamp(-limit, limit)
	var excess: Vector2 = raw - clamped
	return Vector2(_resist(excess.x), _resist(excess.y))

func _resist(amount: float) -> float:
	if amount == 0.0 or max_overscroll <= 0.0:
		return 0.0
	return signf(amount) * max_overscroll * (1.0 - exp(-absf(amount) / max_overscroll))

# Diminishing pull past [low, high]: inside the range it's identity; outside it asymptotes [param give]
# beyond the edge.
func _rubber_scalar(value: float, low: float, high: float, give: float) -> float:
	if give <= 0.0:
		return clampf(value, low, high)
	if value < low:
		return low - give * (1.0 - exp(-(low - value) / give))
	if value > high:
		return high + give * (1.0 - exp(-(value - high) / give))
	return value
