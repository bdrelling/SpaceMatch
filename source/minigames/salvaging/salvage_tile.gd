class_name SalvageTile
extends GridTile
## One scrap cell: covered, flagged, a hidden object, or an adjacency number. The board sets plain
## display flags; [member style] swings what a hidden object and a flag read as — a hazard mine to
## avoid, or a damaged-module chip to claim. Draws in pixel space (undoing the grid's cell-size scale)
## to keep exact edge widths and crisp numbers.

## How a hidden object and a flag are drawn: a mine to dodge, or salvageable loot.
enum Style { HAZARD, SALVAGE }

const _COLOR_COVERED := Color(0.36, 0.34, 0.31)
const _COLOR_COVERED_EDGE := Color(0.46, 0.43, 0.39)
const _COLOR_REVEALED := Color(0.20, 0.19, 0.17)
const _COLOR_REVEALED_EDGE := Color(0.28, 0.27, 0.24)
const _COLOR_MINE := Color(0.85, 0.32, 0.27)
const _COLOR_MINE_HIT := Color(0.95, 0.45, 0.25)
const _COLOR_FLAG := Color(0.93, 0.76, 0.32)
const _COLOR_MODULE := Color(0.36, 0.78, 0.66)
const _COLOR_MODULE_MARK := Color(0.36, 0.78, 0.66, 0.6)
## Adjacency-count tints, index 1..8.
const _NUMBER_COLORS: Array[Color] = [
	Color.TRANSPARENT,
	Color(0.42, 0.74, 0.95),
	Color(0.47, 0.80, 0.42),
	Color(0.93, 0.45, 0.42),
	Color(0.70, 0.52, 0.93),
	Color(0.95, 0.62, 0.33),
	Color(0.40, 0.82, 0.83),
	Color(0.86, 0.86, 0.90),
	Color(0.65, 0.65, 0.70),
]

var style: Style = Style.HAZARD
var revealed: bool = false
var flagged: bool = false
## A hidden object lives here — a mine (HAZARD) or a damaged module (SALVAGE).
var object: bool = false
var adjacent: int = 0
## The run was lost — exposed mines that weren't flagged show the hit tint.
var lost: bool = false

var _font: Font = ThemeDB.fallback_font

func _draw() -> void:
	var cell_pixels: float = scale.x
	if cell_pixels <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / cell_pixels)
	var rect := Rect2(0.0, 0.0, cell_pixels - 2.0, cell_pixels - 2.0)
	if not revealed:
		draw_rect(rect, _COLOR_COVERED)
		draw_rect(rect, _COLOR_COVERED_EDGE, false, 2.0)
		if flagged:
			if style == Style.SALVAGE:
				_draw_module(rect, _COLOR_MODULE_MARK, false)
			else:
				_draw_flag(rect)
		return
	draw_rect(rect, _COLOR_REVEALED)
	draw_rect(rect, _COLOR_REVEALED_EDGE, false, 1.0)
	if object:
		if style == Style.SALVAGE:
			_draw_module(rect, _COLOR_MODULE, true)
		else:
			var mine_color: Color = _COLOR_MINE_HIT if lost and not flagged else _COLOR_MINE
			draw_circle(rect.position + rect.size * 0.5, rect.size.x * 0.22, mine_color)
	elif adjacent > 0:
		_draw_number(rect)

func _draw_flag(rect: Rect2) -> void:
	var base: Vector2 = rect.position + Vector2(rect.size.x * 0.4, rect.size.y * 0.72)
	var top: Vector2 = base - Vector2(0.0, rect.size.y * 0.44)
	draw_line(base, top, _COLOR_FLAG, 3.0)
	draw_colored_polygon(PackedVector2Array([
		top,
		top + Vector2(rect.size.x * 0.26, rect.size.y * 0.1),
		top + Vector2(0.0, rect.size.y * 0.2),
	]), _COLOR_FLAG)

# A damaged-module chip: a rounded body with two leads, filled when salvaged or hollow as a planning
# marker.
func _draw_module(rect: Rect2, color: Color, filled: bool) -> void:
	var body := Rect2(rect.position + rect.size * 0.28, rect.size * 0.44)
	if filled:
		draw_rect(body, color)
		draw_rect(body, color.darkened(0.35), false, 2.0)
	else:
		draw_rect(body, color, false, 2.0)
	var lead_color: Color = color.darkened(0.2) if filled else color
	var inset: float = body.size.x * 0.28
	var stub: float = rect.size.y * 0.08
	draw_line(body.position + Vector2(inset, 0.0), body.position + Vector2(inset, -stub), lead_color, 2.0)
	draw_line(body.position + Vector2(body.size.x - inset, 0.0), body.position + Vector2(body.size.x - inset, -stub), lead_color, 2.0)

func _draw_number(rect: Rect2) -> void:
	var text: String = str(adjacent)
	var font_size: int = int(rect.size.y * 0.58)
	var extent: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin: Vector2 = rect.position + Vector2(
		(rect.size.x - extent.x) * 0.5,
		(rect.size.y + extent.y * 0.7) * 0.5,
	)
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _NUMBER_COLORS[adjacent])
