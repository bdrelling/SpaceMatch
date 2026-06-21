class_name MatchTile
extends GridTile
## A component tile for the match-3 board: one of six glyphs (combat, propulsion, science, defense,
## scrap, anomaly) chosen by [member kind], drawn centred on the node origin in unit cell-space so a pop
## scales about the centre. Filled with [member tint] when the host sets it, else a built-in palette.
##
## Scrap is the only hexagon (flat-top, with a bolt hole); Science is an atom (three rounded oval orbits
## around a nucleus), so the glyphs stay distinct at a glance.

const KIND_COUNT: int = 6

## Display names per kind, index-aligned with [constant _COLORS]. The purple pentagon has no role yet —
## it's an unnamed placeholder, labelled by its shape until one is assigned.
const NAMES: Array[String] = ["Combat", "Propulsion", "Science", "Defense", "Scrap", "Pentagon"]

const _COLORS: Array[Color] = [
	Color(0.88, 0.33, 0.34),  # combat — red diamond
	Color(0.97, 0.80, 0.30),  # propulsion — yellow engine pod
	Color(0.44, 0.78, 0.50),  # science — green atom (three oval orbits)
	Color(0.35, 0.68, 0.92),  # defense — teal-blue shield
	Color(0.60, 0.64, 0.70),  # scrap — grey nut (flat-top hexagon + bolt hole)
	Color(0.66, 0.47, 0.86),  # (unassigned) — purple pentagon
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
			_draw_diamond(color)
		1:
			_draw_thruster(color, detail)
		2:
			_draw_atom(color)
		3:
			_draw_shield(color)
		4:
			_draw_nut(color, detail)
		_:
			_draw_pentagon(color)
	if _highlighted:
		var inset: float = _HALF + 0.05
		draw_rect(Rect2(Vector2(-inset, -inset), Vector2(inset * 2.0, inset * 2.0)), Color.WHITE, false, _LINE * 1.4)

# --- glyphs (centred on origin) ---

# Combat — a tall diamond (rhombus), points up/down.
func _draw_diamond(color: Color) -> void:
	var w: float = _HALF * 0.82
	var h: float = _HALF
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -h), Vector2(w, 0.0), Vector2(0.0, h), Vector2(-w, 0.0)]), color)

# Propulsion — a little engine pod: a capsule body with a porthole and a flared nozzle skirt.
func _draw_thruster(color: Color, detail: Color) -> void:
	var bw: float = _HALF * 0.42
	var dome_y: float = -_HALF + bw
	var nozzle_bottom: float = _HALF * 0.95
	var nozzle_top: float = nozzle_bottom - _HALF * 0.3
	# Capsule body: a domed top over a rectangle.
	draw_circle(Vector2(0.0, dome_y), bw, color)
	draw_rect(Rect2(Vector2(-bw, dome_y), Vector2(bw * 2.0, nozzle_top - dome_y)), color)
	# Flared nozzle skirt under the body.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-bw * 0.72, nozzle_top), Vector2(bw * 0.72, nozzle_top),
		Vector2(bw * 1.25, nozzle_bottom), Vector2(-bw * 1.25, nozzle_bottom)]), detail)
	# Porthole.
	draw_circle(Vector2(0.0, (dome_y + nozzle_top) * 0.5), bw * 0.42, detail)

# Science — an atom: three rounded oval orbits 60° apart (a hexagonally symmetric ring) around a nucleus.
func _draw_atom(color: Color) -> void:
	var rx: float = _HALF
	var ry: float = _HALF * 0.5
	var width: float = _HALF * 0.11
	# Rotated 30° so one oval stands vertical — a lobe points straight up.
	for rot: float in [PI / 6.0, PI / 2.0, PI * 5.0 / 6.0]:
		_draw_orbit(rx, ry, rot, color, width)
	draw_circle(Vector2.ZERO, _HALF * 0.26, color)

# An ellipse outline centred on the origin, its major axis rotated by [param rot] — one electron orbit.
func _draw_orbit(rx: float, ry: float, rot: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var t: float = float(i) / 48.0 * TAU
		pts.append(Vector2(cos(t) * rx, sin(t) * ry).rotated(rot))
	draw_polyline(pts, color, width)

# Defense — a heater shield: flat top edge, slightly bowed sides tapering to a point. Sized to a roughly
# square footprint (not the full cell height) so it sits contained like the other glyphs, not elongated.
func _draw_shield(color: Color) -> void:
	var w: float = _HALF * 0.85
	var top: float = -_HALF * 0.8
	var bottom: float = _HALF * 0.9
	var p0 := Vector2(w, top)                  # top-right corner
	var p1 := Vector2(w * 1.03, _HALF * 0.22)  # control — bows the right side out a touch
	var p2 := Vector2(0.0, bottom)             # bottom point
	var steps: int = 14
	var right := PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		right.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	var pts := PackedVector2Array()
	pts.append(Vector2(-w, top))              # top-left corner (flat top edge runs to the top-right)
	pts.append_array(right)                   # down the rounded right side to the point
	for i in range(steps - 1, 0, -1):         # up the mirrored left side
		pts.append(Vector2(-right[i].x, right[i].y))
	draw_colored_polygon(pts, color)

# Scrap — a flat-top hexagon (rotated ~30° off the science hexagon) with a bolt hole in the centre.
func _draw_nut(color: Color, detail: Color) -> void:
	draw_colored_polygon(_ngon(6, _HALF, 0.0), color)
	draw_circle(Vector2.ZERO, _HALF * 0.4, detail)

# Anomaly — a pointy-top pentagon (placeholder kind).
func _draw_pentagon(color: Color) -> void:
	draw_colored_polygon(_ngon(5, _HALF, -PI / 2.0), color)

# --- shape builders ---

func _ngon(sides: int, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in sides:
		var angle: float = rotation + index * TAU / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
