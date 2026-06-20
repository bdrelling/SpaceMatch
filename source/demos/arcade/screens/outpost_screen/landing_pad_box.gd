class_name LandingPadBox
extends Control
## One landing pad in the outpost screen: a framed box with the docked ship's module grid as a low-res
## [ShipGridThumbnail], the pad number, and the occupant's name — or "Empty". A ghost box (dashed
## border, no thumbnail) stands in for the next pad the player could buy; display only, no purchase yet.

const _PAD_SIZE := Vector2(220.0, 220.0)
const _THUMB_INSET := 16.0
## Space reserved at the bottom for the pad's label.
const _LABEL_BAND := 44.0
const _DASH := 10.0
const _LABEL_FONT_SIZE := 22

const _BACKGROUND := Color(0.13, 0.16, 0.25)
const _BORDER := Color(1, 1, 1, 0.18)
const _GHOST_BORDER := Color(1, 1, 1, 0.32)
const _LABEL := Color(0.85, 0.88, 0.95)
const _MUTED := Color(0.6, 0.64, 0.72)

## Set before adding to the tree.
var index: int = 0
var pad: LandingPadState
var ghost: bool = false

var _thumbnail: ShipGridThumbnail

func _ready() -> void:
	custom_minimum_size = _PAD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ghost and pad != null and pad.occupant != null:
		_thumbnail = ShipGridThumbnail.new()
		_thumbnail.grid = pad.occupant.module_grid
		_thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_thumbnail)
	resized.connect(_layout_thumbnail)
	_layout_thumbnail()

func _layout_thumbnail() -> void:
	if _thumbnail == null:
		return
	_thumbnail.position = Vector2(_THUMB_INSET, _THUMB_INSET)
	_thumbnail.size = Vector2(
		maxf(size.x - _THUMB_INSET * 2.0, 0.0),
		maxf(size.y - _THUMB_INSET - _LABEL_BAND, 0.0))

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if ghost:
		_draw_dashed_border(rect, _GHOST_BORDER)
		_draw_label("Next pad", _MUTED)
		return
	draw_rect(rect, _BACKGROUND)
	draw_rect(rect, _BORDER, false, 1.0)
	if pad != null and pad.occupant != null:
		_draw_label("Pad %d — %s" % [index + 1, pad.occupant.name], _LABEL)
	else:
		_draw_label("Pad %d — Empty" % [index + 1], _MUTED)

func _draw_label(text: String, color: Color) -> void:
	draw_string(
		ThemeDB.fallback_font, Vector2(12.0, size.y - 16.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, _LABEL_FONT_SIZE, color)

func _draw_dashed_border(rect: Rect2, color: Color) -> void:
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for index: int in corners.size():
		_dashed_line(corners[index], corners[(index + 1) % corners.size()], color)

func _dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var length: float = from.distance_to(to)
	if length <= 0.0:
		return
	var step: Vector2 = (to - from) / length
	var traveled: float = 0.0
	while traveled < length:
		draw_line(from + step * traveled, from + step * minf(traveled + _DASH, length), color, 1.5)
		traveled += _DASH * 2.0
