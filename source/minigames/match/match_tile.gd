class_name MatchTile
extends GridTile
## A component tile for the match-3 board: one of six glyphs (wire, tube, panel, bolt, gear, coil)
## chosen by [member kind], drawn centred on the node origin in unit cell-space so a pop scales about the
## centre. Filled with [member tint] when the host sets it (the component's colour), else a built-in palette.

const KIND_COUNT: int = 6

## Display names per kind, index-aligned with [constant _COLORS] and the host's component catalog.
const NAMES: Array[String] = ["Wire", "Tube", "Panel", "Bolt", "Gear", "Coil"]

const _COLORS: Array[Color] = [
	Color(0.85, 0.50, 0.25),  # wire — copper
	Color(0.55, 0.62, 0.58),  # tube — steel
	Color(0.45, 0.55, 0.75),  # panel — slate blue
	Color(0.96, 0.74, 0.26),  # bolt — brass
	Color(0.66, 0.47, 0.86),  # gear — violet
	Color(0.30, 0.79, 0.74),  # coil — teal
]
## Glyph half-extent in cell units; leaves a margin inside the cell.
const _HALF: float = 0.40
const _LINE: float = 0.045

## Glyph color for [param kind], clamped to the catalog.
static func color_of(kind: int) -> Color:
	return _COLORS[clampi(kind, 0, _COLORS.size() - 1)]

var kind: int = 0:
	set(value):
		kind = value
		queue_redraw()

## Fill override painted by the host (the component blueprint's colour). Zero
## alpha means unset — the built-in palette is used instead.
var tint: Color = Color(0, 0, 0, 0):
	set(value):
		tint = value
		queue_redraw()

var _highlighted: bool = false

func set_highlighted(on: bool) -> void:
	if _highlighted == on:
		return
	_highlighted = on
	queue_redraw()

func _draw() -> void:
	var color: Color = tint if tint.a > 0.0 else _COLORS[clampi(kind, 0, _COLORS.size() - 1)]
	var detail: Color = color.darkened(0.5)
	match kind:
		0:
			_draw_wire(color, detail)
		1:
			_draw_tube(color, detail)
		2:
			_draw_panel(color, detail)
		3:
			_draw_bolt(color, detail)
		4:
			_draw_gear(color, detail)
		_:
			_draw_coil(color, detail)
	if _highlighted:
		var inset: float = _HALF + 0.05
		draw_rect(Rect2(Vector2(-inset, -inset), Vector2(inset * 2.0, inset * 2.0)), Color.WHITE, false, _LINE * 1.4)

# --- glyphs (centred on origin) ---

func _draw_wire(color: Color, detail: Color) -> void:
	var points := PackedVector2Array()
	var steps: int = 24
	for index: int in steps + 1:
		var t: float = float(index) / float(steps)
		var x: float = lerpf(-_HALF, _HALF, t)
		var y: float = sin(t * TAU * 1.5) * _HALF * 0.5
		points.append(Vector2(x, y))
	draw_polyline(points, color, _LINE * 2.2)
	draw_circle(points[0], _HALF * 0.16, detail)
	draw_circle(points[points.size() - 1], _HALF * 0.16, detail)

func _draw_tube(color: Color, detail: Color) -> void:
	draw_circle(Vector2.ZERO, _HALF, color)
	draw_circle(Vector2.ZERO, _HALF * 0.55, detail)
	draw_arc(Vector2.ZERO, _HALF * 0.78, 0.0, TAU, 24, color.lightened(0.25), _LINE)

func _draw_panel(color: Color, detail: Color) -> void:
	draw_rect(Rect2(Vector2(-_HALF, -_HALF * 0.78), Vector2(_HALF * 2.0, _HALF * 1.56)), color)
	var rivet: float = _HALF * 0.6
	for corner: Vector2 in [Vector2(-rivet, -rivet * 0.78), Vector2(rivet, -rivet * 0.78), Vector2(-rivet, rivet * 0.78), Vector2(rivet, rivet * 0.78)]:
		draw_circle(corner, _HALF * 0.12, detail)

func _draw_bolt(color: Color, detail: Color) -> void:
	draw_colored_polygon(_ngon(6, _HALF, PI / 6.0), color)
	draw_circle(Vector2.ZERO, _HALF * 0.4, detail)

func _draw_gear(color: Color, detail: Color) -> void:
	draw_colored_polygon(_cog(8, _HALF, _HALF * 0.74), color)
	draw_circle(Vector2.ZERO, _HALF * 0.32, detail)

func _draw_coil(color: Color, detail: Color) -> void:
	var turns: float = 2.5
	var steps: int = 48
	var points := PackedVector2Array()
	for index: int in steps + 1:
		var t: float = float(index) / float(steps)
		var radius: float = lerpf(_HALF * 0.18, _HALF, t)
		var angle: float = t * TAU * turns
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, _LINE * 2.0)
	draw_circle(Vector2.ZERO, _HALF * 0.16, detail)

# --- shape builders ---

func _ngon(sides: int, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in sides:
		var angle: float = rotation + index * TAU / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _cog(teeth: int, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps: int = teeth * 2
	for index: int in steps:
		var angle: float = index * TAU / float(steps)
		var radius: float = outer if index % 2 == 0 else inner
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
