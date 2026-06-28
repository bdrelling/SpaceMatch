class_name MatchTile
extends GridTile
## A component tile for the match-3 board: one of seven kinds (combat, propulsion, science, defense,
## scrap, warp, damage) chosen by [member kind], drawn centred on the node origin in unit cell-space so
## a pop scales about the centre. Kinds 0–5 render a sprite from [constant _TEXTURES]; damage (kind 6)
## has no art yet, so it falls back to a hand-drawn starburst. A non-zero [member tint] modulates the art.

const KIND_COUNT: int = 7

## Display names per kind, index-aligned with [constant _COLORS] and [constant _TEXTURES].
const NAMES: Array[String] = ["Combat", "Propulsion", "Science", "Defense", "Scrap", "Warp", "Damage"]

## Sprite per kind, index-aligned with [constant NAMES]. Kinds 0–5 have art; damage (kind 6) is drawn.
const _TEXTURES: Array[Texture2D] = [
	preload("res://assets/tiles/combat.png"),
	preload("res://assets/tiles/propulsion.png"),
	preload("res://assets/tiles/science.png"),
	preload("res://assets/tiles/defense.png"),
	preload("res://assets/tiles/scrap.png"),
	preload("res://assets/tiles/warp.png"),
]

## Fallback palette for kinds without art (and the source of [method color_of] for HUD readouts).
const _COLORS: Array[Color] = [
	Color(0.88, 0.33, 0.34),  # combat
	Color(0.97, 0.80, 0.30),  # propulsion
	Color(0.44, 0.78, 0.50),  # science
	Color(0.35, 0.68, 0.92),  # defense
	Color(0.60, 0.64, 0.70),  # scrap
	Color(0.66, 0.47, 0.86),  # warp
	Color(0.96, 0.50, 0.18),  # damage — orange starburst (explosion)
]
## Glyph half-extent in cell units; leaves a margin inside the cell.
const _HALF: float = 0.40
const _LINE: float = 0.045

## Sprite per kind, or null for a kind drawn procedurally (damage).
static func texture_of(kind: int) -> Texture2D:
	return _TEXTURES[kind] if kind >= 0 and kind < _TEXTURES.size() else null

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

## Owner outline painted by the host on a shared board — the colour of the side that owns this tile (blue
## player, red opponent). Zero alpha means unowned/neutral and draws no ring. Drawn distinct from the white
## selection highlight, which still draws over it.
var owner_outline: Color = Color(0, 0, 0, 0):
	set(value):
		owner_outline = value
		queue_redraw()

var _highlighted: bool = false

func _init() -> void:
	# Mipmapped sampling so the high-res art downscales cleanly into a board cell.
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func set_highlighted(on: bool) -> void:
	if _highlighted == on:
		return
	_highlighted = on
	queue_redraw()

func _draw() -> void:
	var texture: Texture2D = texture_of(kind)
	if texture != null:
		# Sprite fills the unit cell; a set tint modulates it, else draw it as authored.
		var modulate_color: Color = tint if tint.a > 0.0 else Color.WHITE
		draw_texture_rect(texture, Rect2(-0.5, -0.5, 1.0, 1.0), false, modulate_color)
	else:
		# Damage (kind 6) has no art yet — fall back to the hand-drawn starburst.
		var color: Color = tint if tint.a > 0.0 else _COLORS[clampi(kind, 0, _COLORS.size() - 1)]
		_draw_explosion(color)
	if owner_outline.a > 0.0:
		var owner_inset: float = _HALF + 0.02
		draw_rect(Rect2(Vector2(-owner_inset, -owner_inset), Vector2(owner_inset * 2.0, owner_inset * 2.0)), owner_outline, false, _LINE * 1.6)
	if _highlighted:
		var inset: float = _HALF + 0.05
		draw_rect(Rect2(Vector2(-inset, -inset), Vector2(inset * 2.0, inset * 2.0)), Color.WHITE, false, _LINE * 1.4)

# Damage — a spiky starburst (an explosion): eight points alternating a long and short radius, with a
# hot, lightened core. The one kind still drawn (no sprite yet).
func _draw_explosion(color: Color) -> void:
	var spikes: int = 8
	var outer: float = _HALF
	var inner: float = _HALF * 0.46
	var burst := PackedVector2Array()
	for index: int in spikes * 2:
		var radius: float = outer if index % 2 == 0 else inner
		var angle: float = -PI / 2.0 + float(index) * PI / float(spikes)
		burst.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(burst, color)
	draw_circle(Vector2.ZERO, _HALF * 0.34, color.lightened(0.5))

# --- collision baking ---

## Traces a unit-cell-space collision outline from each kind's sprite alpha. Returns one polygon per
## entry in [constant _TEXTURES] (kinds 0–5); kinds without art are left to a procedural fallback.
## [param alpha_threshold] is the opaque cutoff (0–1); [param epsilon] simplifies the traced outline.
static func bake_collision_outlines(alpha_threshold: float, epsilon: float) -> Array[PackedVector2Array]:
	var outlines: Array[PackedVector2Array] = []
	for texture: Texture2D in _TEXTURES:
		outlines.append(_trace_outline(texture, alpha_threshold, epsilon))
	return outlines

# The largest opaque silhouette of [param texture], normalised so the full image spans the unit cell
# (−0.5…0.5) centred on the origin — matching how [method _draw] lays the sprite down.
static func _trace_outline(texture: Texture2D, alpha_threshold: float, epsilon: float) -> PackedVector2Array:
	var image: Image = texture.get_image()
	if image == null:
		return PackedVector2Array()
	var size: Vector2i = image.get_size()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, alpha_threshold)
	var polygons: Array[PackedVector2Array] = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), epsilon)
	var biggest := PackedVector2Array()
	var best_area: float = -1.0
	for polygon: PackedVector2Array in polygons:
		var area: float = absf(_signed_area(polygon))
		if area > best_area:
			best_area = area
			biggest = polygon
	var normalised := PackedVector2Array()
	for point: Vector2 in biggest:
		normalised.append(Vector2(point.x / size.x - 0.5, point.y / size.y - 0.5))
	return normalised

static func _signed_area(polygon: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return total * 0.5
