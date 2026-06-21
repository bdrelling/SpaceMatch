extends Control
## Throwaway sheet. Top = the six (half-size line). Below = a yellow TRIANGLE gem with 12 different
## chevron/arrowhead/triangle symbols inside, numbered 1–12.

const _BG := Color(0.09, 0.08, 0.13)
const _INK := Color(0.66, 0.72, 0.85)
const _TITLE := Color(0.82, 0.86, 0.97)
const _LOCK := Color(0.55, 0.78, 0.62)
const _RED := Color(0.88, 0.33, 0.34)
const _YELLOW := Color(0.97, 0.8, 0.3)
const _GREEN := Color(0.44, 0.78, 0.5)
const _BLUE := Color(0.35, 0.68, 0.92)
const _GRAY := Color(0.6, 0.64, 0.7)
const _PURPLE := Color(0.66, 0.47, 0.86)

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _BG)
	var font := ThemeDB.fallback_font

	draw_string(font, Vector2(0.0, size.y * 0.035), "— the six —", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, _LOCK)
	var cwn := size.x / 6.0
	var hs := cwn * 0.3
	var six: Array[String] = ["Combat", "Propulsion", "Science", "Defense", "Scrap", "Swirl"]
	for i in 6:
		var c := Vector2((float(i) + 0.5) * cwn, size.y * 0.1)
		_six(i, c, hs)
		draw_string(font, Vector2(c.x - cwn * 0.5, c.y + hs + 26.0), six[i], HORIZONTAL_ALIGNMENT_CENTER, cwn, 18, _INK)

	draw_string(font, Vector2(0.0, size.y * 0.21), "— propulsion: yellow triangle + chevron/arrow (pick a number) —",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, _TITLE)
	var cw4 := size.x / 4.0
	var h := cw4 * 0.3
	var ink := _YELLOW.darkened(0.45)
	for n in 12:
		var col := n % 4
		var row := n / 4
		var c := Vector2((float(col) + 0.5) * cw4, size.y * (0.34 + float(row) * 0.18))
		_gem(_tri(c, h), c, _YELLOW)
		var sc := Vector2(c.x, c.y + h * 0.12)
		var s := h * 0.4
		_inside(n, sc, s, ink)
		draw_string(font, Vector2(c.x - cw4 * 0.5, c.y + h * 0.55 + 40.0), str(n + 1), HORIZONTAL_ALIGNMENT_CENTER, cw4, 30, _INK)

func _inside(n: int, c: Vector2, s: float, col: Color) -> void:
	match n:
		0: _chev(c, s, 1, col, 0.7, 0.5)
		1: _chev(c, s, 2, col, 0.7, 0.5)
		2: _chev(c, s, 3, col, 0.7, 0.5)
		3: _solid(c, s, 1, col)
		4: _solid(c, s, 2, col)
		5: _solid(c, s, 3, col)
		6: _hollow(c, s, 1, col)
		7: _hollow(c, s, 2, col)
		8: _chev(c, s, 2, col, 0.95, 0.38)
		9: _chev(c, s, 3, col, 0.5, 0.6)
		10:
			_solid(c + Vector2(0.0, s * 0.35), s * 0.85, 1, col)
			_chev(c + Vector2(0.0, -s * 0.4), s * 0.7, 1, col, 0.7, 0.5)
		_: _solid(c, s * 1.25, 1, col)

# --- candidate symbols ---

func _chev(c: Vector2, s: float, count: int, col: Color, hw: float, vh: float) -> void:
	var w := s * 0.2
	var dy := s * 0.5
	var total := float(count - 1) * dy
	for k in count:
		var yo := c.y - total * 0.5 + float(k) * dy
		draw_polyline(PackedVector2Array([
			Vector2(c.x - s * hw, yo + s * vh * 0.5), Vector2(c.x, yo - s * vh * 0.5),
			Vector2(c.x + s * hw, yo + s * vh * 0.5)]), col, w)

func _solid(c: Vector2, s: float, count: int, col: Color) -> void:
	var dy := s * 0.52
	var total := float(count - 1) * dy
	for k in count:
		var yo := c.y - total * 0.5 + float(k) * dy
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x, yo - s * 0.42), Vector2(c.x + s * 0.62, yo + s * 0.26), Vector2(c.x - s * 0.62, yo + s * 0.26)]), col)

func _hollow(c: Vector2, s: float, count: int, col: Color) -> void:
	for k in count:
		var r := s * (1.0 - float(k) * 0.42)
		var p := _ngon(c, 3, r, -PI / 2.0)
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, col, s * 0.16)

# --- the six helpers ---

func _six(i: int, c: Vector2, h: float) -> void:
	match i:
		0:
			_gem(_diamond(c, h), c, _RED)
			_ch_ring(c, h * 0.55, _RED.darkened(0.45))
		1: _pod(c, h, _YELLOW)
		2:
			_gem(_ngon(c, 6, h, PI / 6.0), c, _GREEN)
			_atom(c, h * 0.5, _GREEN.darkened(0.42))
		3: _gem(_shield(c, h), c, _BLUE)
		4: _gear(c, h, _GRAY)
		_:
			_gem_circle(c, h, _PURPLE)
			_swirl(c, h * 0.6, _PURPLE.darkened(0.42))

func _gem(pts: PackedVector2Array, c: Vector2, base: Color) -> void:
	draw_colored_polygon(pts, base)
	var inner := PackedVector2Array()
	for p: Vector2 in pts:
		inner.append(c + (p - c) * 0.58)
	draw_colored_polygon(inner, base.lightened(0.22))
	_spec(c, base, pts[0].distance_to(c))

func _gem_circle(c: Vector2, h: float, base: Color) -> void:
	draw_circle(c, h, base)
	draw_circle(c, h * 0.58, base.lightened(0.22))
	_spec(c, base, h)

func _spec(c: Vector2, base: Color, span: float) -> void:
	var hi := base.lightened(0.5)
	hi.a = 0.3
	draw_circle(c + Vector2(0.0, -span * 0.45), span * 0.17, hi)

func _ngon(c: Vector2, sides: int, rad: float, rot: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in sides:
		var a := rot + float(i) * TAU / float(sides)
		p.append(c + Vector2(cos(a), sin(a)) * rad)
	return p

func _tri(c: Vector2, h: float) -> PackedVector2Array:
	return _ngon(c, 3, h, -PI / 2.0)

func _diamond(c: Vector2, h: float) -> PackedVector2Array:
	var w := h * 0.82
	return PackedVector2Array([Vector2(c.x, c.y - h), Vector2(c.x + w, c.y), Vector2(c.x, c.y + h), Vector2(c.x - w, c.y)])

func _shield(c: Vector2, h: float) -> PackedVector2Array:
	var w := h * 0.85
	var top := c.y - h * 0.8
	var p0 := Vector2(c.x + w, top)
	var p1 := Vector2(c.x + w * 1.03, c.y + h * 0.22)
	var p2 := Vector2(c.x, c.y + h * 0.9)
	var right := PackedVector2Array()
	for i in 15:
		var t := float(i) / 14.0
		right.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	var pts := PackedVector2Array()
	pts.append(Vector2(c.x - w, top))
	pts.append_array(right)
	for i in range(13, 0, -1):
		pts.append(Vector2(2.0 * c.x - right[i].x, right[i].y))
	return pts

func _gear(c: Vector2, h: float, base: Color) -> void:
	var rb := h * 0.78
	draw_circle(c, rb, base)
	for i in 8:
		var a := float(i) * TAU / 8.0
		var d := Vector2(cos(a), sin(a))
		var p := Vector2(-sin(a), cos(a))
		draw_colored_polygon(PackedVector2Array([
			c + d * rb * 0.9 + p * h * 0.155, c + d * h * 0.92 + p * h * 0.155,
			c + d * h * 0.92 - p * h * 0.155, c + d * rb * 0.9 - p * h * 0.155]), base)
	draw_circle(c, rb * 0.8, base.lightened(0.2))
	_spec(c, base, h)
	draw_circle(c, h * 0.22, base.darkened(0.42))

func _pod(c: Vector2, h: float, color: Color) -> void:
	var detail := color.darkened(0.45)
	var bw := h * 0.42
	var dome := c.y - h + bw
	var nb := c.y + h * 0.95
	var nt := nb - h * 0.3
	draw_circle(Vector2(c.x, dome), bw, color)
	draw_rect(Rect2(c.x - bw, dome, bw * 2.0, nt - dome), color)
	draw_circle(Vector2(c.x, (dome + nt) * 0.5), bw * 0.35, color.lightened(0.25))
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - bw * 0.72, nt), Vector2(c.x + bw * 0.72, nt),
		Vector2(c.x + bw * 1.25, nb), Vector2(c.x - bw * 1.25, nb)]), detail)

func _atom(c: Vector2, r: float, color: Color) -> void:
	for rot: float in [PI / 6.0, PI / 2.0, PI * 5.0 / 6.0]:
		var e := PackedVector2Array()
		for k in 49:
			var t := float(k) / 48.0 * TAU
			e.append(c + Vector2(cos(t) * r, sin(t) * r * 0.5).rotated(rot))
		draw_polyline(e, color, r * 0.13)
	draw_circle(c, r * 0.26, color)

func _swirl(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 65:
		var t := float(i) / 64.0
		pts.append(c + Vector2(cos(t * TAU * 2.2), sin(t * TAU * 2.2)) * lerpf(r * 0.08, r, t))
	draw_polyline(pts, color, r * 0.16)

func _ch_ring(c: Vector2, r: float, color: Color) -> void:
	draw_arc(c, r * 0.62, 0.0, TAU, 40, color, r * 0.16)
	for a: float in [-PI / 2.0, 0.0, PI / 2.0, PI]:
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.66, c + d * r, color, r * 0.16)
	draw_circle(c, r * 0.13, color)
