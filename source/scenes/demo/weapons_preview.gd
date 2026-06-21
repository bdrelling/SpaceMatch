extends Control
## Throwaway sheet: the six tile glyphs today + the six proposed combat candidates (3 crosshairs, 3 explosions).

const _BG := Color(0.09, 0.08, 0.13)
const _INK := Color(0.66, 0.72, 0.85)
const _TITLE := Color(0.82, 0.86, 0.97)
const _RED := Color(0.88, 0.33, 0.34)
const _YELLOW := Color(0.97, 0.8, 0.3)
const _GREEN := Color(0.44, 0.78, 0.5)
const _BLUE := Color(0.35, 0.68, 0.92)
const _GRAY := Color(0.6, 0.64, 0.7)
const _PURPLE := Color(0.66, 0.47, 0.86)
const _ORANGE := Color(0.96, 0.52, 0.22)
const _HOT := Color(0.99, 0.8, 0.4)

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _BG)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, 70.0), "Six today  +  six proposed combat",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, _TITLE)

	var cw := size.x / 3.0
	var r := cw * 0.2

	draw_string(font, Vector2(0.0, size.y * 0.1), "— the six today —",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, _INK)
	var today: Array[String] = ["Combat", "Propulsion", "Science", "Defense", "Scrap", "Pentagon"]
	for i in 6:
		var c := Vector2((float(i % 3) + 0.5) * cw, size.y * (0.165 if i / 3 == 0 else 0.32))
		match i:
			0: _diamond(c, r, _RED)
			1: _pod(c, r, _YELLOW)
			2: _atom(c, r, _GREEN)
			3: _shield(c, r, _BLUE)
			4: _nut(c, r, _GRAY)
			_: _pent(c, r, _PURPLE)
		draw_string(font, Vector2(c.x - cw * 0.5, c.y + r + 40.0), today[i],
			HORIZONTAL_ALIGNMENT_CENTER, cw, 28, _INK)

	draw_string(font, Vector2(0.0, size.y * 0.45), "— six proposed combat —",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, _TITLE)
	var prop: Array[String] = ["Crosshair 1", "Crosshair 2", "Crosshair 3", "Explosion 1", "Explosion 2", "Explosion 3"]
	for j in 6:
		var c := Vector2((float(j % 3) + 0.5) * cw, size.y * (0.53 if j / 3 == 0 else 0.68))
		match j:
			0: _ch_classic(c, r)
			1: _ch_brackets(c, r)
			2: _ch_segmented(c, r)
			3: _e1(c, r)
			4: _e2(c, r)
			_: _e3(c, r)
		draw_string(font, Vector2(c.x - cw * 0.5, c.y + r + 40.0), prop[j],
			HORIZONTAL_ALIGNMENT_CENTER, cw, 28, _INK)

func _ngon(c: Vector2, sides: int, rad: float, rot: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in sides:
		var a := rot + float(i) * TAU / float(sides)
		p.append(c + Vector2(cos(a), sin(a)) * rad)
	return p

# --- the six today ---

func _diamond(c: Vector2, r: float, color: Color) -> void:
	var w := r * 0.82
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - r), Vector2(c.x + w, c.y), Vector2(c.x, c.y + r), Vector2(c.x - w, c.y)]), color)

func _pod(c: Vector2, r: float, color: Color) -> void:
	var detail := color.darkened(0.5)
	var bw := r * 0.42
	var dome := c.y - r + bw
	var nb := c.y + r * 0.95
	var nt := nb - r * 0.3
	draw_circle(Vector2(c.x, dome), bw, color)
	draw_rect(Rect2(c.x - bw, dome, bw * 2.0, nt - dome), color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - bw * 0.72, nt), Vector2(c.x + bw * 0.72, nt),
		Vector2(c.x + bw * 1.25, nb), Vector2(c.x - bw * 1.25, nb)]), detail)
	draw_circle(Vector2(c.x, (dome + nt) * 0.5), bw * 0.42, detail)

func _atom(c: Vector2, r: float, color: Color) -> void:
	for rot: float in [PI / 6.0, PI / 2.0, PI * 5.0 / 6.0]:
		var e := PackedVector2Array()
		for k in 49:
			var t := float(k) / 48.0 * TAU
			e.append(c + Vector2(cos(t) * r, sin(t) * r * 0.5).rotated(rot))
		draw_polyline(e, color, r * 0.11)
	draw_circle(c, r * 0.26, color)

func _shield(c: Vector2, r: float, color: Color) -> void:
	var w := r * 0.85
	var top := c.y - r * 0.8
	var bottom := c.y + r * 0.9
	var p0 := Vector2(c.x + w, top)
	var p1 := Vector2(c.x + w * 1.03, c.y + r * 0.22)
	var p2 := Vector2(c.x, bottom)
	var steps := 14
	var right := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		right.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	var pts := PackedVector2Array()
	pts.append(Vector2(c.x - w, top))
	pts.append_array(right)
	for i in range(steps - 1, 0, -1):
		pts.append(Vector2(2.0 * c.x - right[i].x, right[i].y))
	draw_colored_polygon(pts, color)

func _nut(c: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(_ngon(c, 6, r, 0.0), color)
	draw_circle(c, r * 0.4, color.darkened(0.5))

func _pent(c: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(_ngon(c, 5, r, -PI / 2.0), color)

# --- proposed: crosshairs ---

func _ch_classic(c: Vector2, r: float) -> void:
	var w := r * 0.11
	draw_arc(c, r * 0.58, 0.0, TAU, 48, _RED, w)
	for a: float in [-PI / 2.0, 0.0, PI / 2.0, PI]:
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.62, c + d * r, _RED, w)
	draw_circle(c, r * 0.1, _RED)

func _ch_brackets(c: Vector2, r: float) -> void:
	var w := r * 0.12
	var s := r * 0.74
	var arm := r * 0.36
	var corners: Array[Vector2] = [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)]
	var dirs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in 4:
		var p := c + corners[i]
		var d := dirs[i]
		draw_line(p, p + Vector2(d.x * arm, 0.0), _RED, w)
		draw_line(p, p + Vector2(0.0, d.y * arm), _RED, w)
	draw_circle(c, r * 0.12, _RED)

func _ch_segmented(c: Vector2, r: float) -> void:
	var w := r * 0.11
	var rad := r * 0.58
	var gap := 0.34
	for k in 4:
		var mid := -PI / 2.0 + float(k) * PI / 2.0
		draw_arc(c, rad, mid + gap, mid + PI / 2.0 - gap, 14, _RED, w)
	for a: float in [-PI / 2.0, 0.0, PI / 2.0, PI]:
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.4, c + d * r * 0.92, _RED, w * 0.85)
	draw_circle(c, r * 0.1, _RED)

# --- proposed: explosions ---

func _burst(c: Vector2, base: float, factors: Array[float], valley: float, rot: float, color: Color) -> void:
	var n := factors.size()
	var pts := PackedVector2Array()
	for i in n * 2:
		var ang := rot + float(i) * PI / float(n)
		var rad := base * factors[i / 2] if i % 2 == 0 else base * valley
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	for i in pts.size():
		draw_colored_polygon(PackedVector2Array([c, pts[i], pts[(i + 1) % pts.size()]]), color)

func _e1(c: Vector2, r: float) -> void:
	var outer: Array[float] = [1.0, 0.72, 0.92, 0.6, 1.0, 0.78, 0.86, 0.64, 0.96, 0.7]
	var inner: Array[float] = [0.95, 0.65, 1.0, 0.7, 0.85, 0.6, 0.95, 0.7, 0.9, 0.65]
	_burst(c, r, outer, 0.42, 0.0, _RED)
	_burst(c, r * 0.6, inner, 0.3, PI / 10.0, _ORANGE)
	draw_circle(c, r * 0.2, _HOT)

func _e2(c: Vector2, r: float) -> void:
	var outer: Array[float] = [1.0, 0.5, 0.82, 0.48, 1.0, 0.58, 0.9, 0.45]
	var inner: Array[float] = [0.9, 0.55, 1.0, 0.6, 0.85, 0.5, 0.95, 0.55]
	_burst(c, r, outer, 0.4, 0.2, _RED)
	_burst(c, r * 0.55, inner, 0.28, 0.2 + PI / 8.0, _ORANGE)
	draw_circle(c, r * 0.2, _HOT)

func _e3(c: Vector2, r: float) -> void:
	var outer: Array[float] = [0.9, 0.7, 0.95, 0.72, 0.88, 0.68, 0.92, 0.7, 0.85, 0.66, 0.9, 0.72]
	var inner: Array[float] = [0.95, 0.75, 0.9, 0.78, 1.0, 0.72, 0.92, 0.76, 0.88, 0.74, 0.95, 0.7]
	_burst(c, r, outer, 0.55, 0.0, _RED)
	_burst(c, r * 0.72, inner, 0.5, PI / 12.0, _ORANGE)
	draw_circle(c, r * 0.3, _HOT)
