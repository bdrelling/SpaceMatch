class_name MatchTile
extends GridTile
## A component tile for the match-3 board: one kind per spawnable [StarshipResource] (combat, propulsion,
## science, defense, scrap, warp, damage, plus any added in-editor), chosen by [member kind] and drawn centred
## on the node origin in unit cell-space so a pop scales about the centre. Its sprite, colour and label come from
## the [StarshipResource] bound to its kind (see [method _resource_for]) — the resources own the tile's
## representation, there is no separate tile-data table, and the set of kinds comes from the resource catalog
## ([method AbilityResourceCatalog.tile_kinds]) rather than a fixed count. The damage tile has no sprite yet, so
## it falls back to a hand-drawn starburst. A non-zero [member tint] modulates the art.

## Glyph half-extent in cell units; leaves a margin inside the cell.
const _HALF: float = 0.40
const _LINE: float = 0.045

# Tile kind -> its StarshipResource, built once from the resource catalog. The resources own the art/colour/label;
# this just indexes them by their id for the board.
static var _by_kind: Dictionary = {}

# The StarshipResource bound to [param kind] (matched on its id), or null when none maps to it.
static func _resource_for(kind: int) -> StarshipResource:
	if _by_kind.is_empty():
		for resource: AbilityResource in Catalogs.ability_resources.ability_resources:
			var starship_resource := resource as StarshipResource
			if starship_resource != null:
				_by_kind[starship_resource.id] = starship_resource
	return _by_kind.get(kind, null)

## Sprite for [param kind], or null for a kind drawn procedurally (damage).
static func texture_of(kind: int) -> Texture2D:
	var resource := _resource_for(kind)
	return resource.texture if resource != null else null

## Glyph colour for [param kind].
static func color_of(kind: int) -> Color:
	var resource := _resource_for(kind)
	return resource.color if resource != null else Color.WHITE

## Display name for [param kind] (empty when none maps to it).
static func name_of(kind: int) -> String:
	var resource := _resource_for(kind)
	return resource.label if resource != null else ""

## Display names for every kind, in kind order — for pickers that list the kinds.
static func names() -> Array[String]:
	var result: Array[String] = []
	for kind: int in Catalogs.ability_resources.tile_kinds():
		result.append(name_of(kind))
	return result

var kind: int = 0:
	set(value):
		kind = value
		queue_redraw()

## Fill override painted by the host (the component blueprint's colour). Zero
## alpha means unset — the resource's colour is used instead.
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
		# Damage (kind 6) has no art yet — fall back to the hand-drawn starburst in the resource's colour.
		var color: Color = tint if tint.a > 0.0 else color_of(kind)
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

## Traces a unit-cell-space collision outline from each kind's sprite alpha. Returns one polygon per kind that
## has a sprite (in kind order); kinds without art are left to a procedural fallback. [param alpha_threshold] is
## the opaque cutoff (0–1); [param epsilon] simplifies the traced outline.
static func bake_collision_outlines(alpha_threshold: float, epsilon: float) -> Array[PackedVector2Array]:
	var outlines: Array[PackedVector2Array] = []
	for kind: int in Catalogs.ability_resources.tile_kinds():
		var resource := _resource_for(kind)
		if resource != null and resource.texture != null:
			outlines.append(_trace_outline(resource.texture, alpha_threshold, epsilon))
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
