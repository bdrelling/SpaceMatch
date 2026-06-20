@tool
class_name CraterStampData
extends TerrainStampData
## Terrain stamp that carves a crater analytically — no EXR required. Set
## radius and depth in real world units; the rest of the shape is internal.
##
## Profile (cross-section) is a flat floor disc rising through a steep wall to
## meet the surrounding ground — no raised rim. The wall is steep through the
## middle but rounded where it meets the floor and the ground: a perfectly
## sharp corner is a slope discontinuity, and sampled on the square terrain
## grid that crease facets into a jagged sawtooth rim. The rounding spans
## several vertices so the rim stays smooth. Only the floor carries gentle
## low-frequency variance so it never looks machined.
##
## Honors the inherited uniform [member TerrainStampData.scale]: footprint and
## depth scale together so per-instance variety reads as bigger/smaller craters.
## [member TerrainStampData.rotation_degrees] turns the outline's warp lobe so
## scattered instances read as differently-oriented ovals.

## Fraction of the radius occupied by the flat floor.
const FLOOR_EDGE: float = 0.5

@export_range(5.0, 200.0, 0.5, "suffix:m") var radius: float = 40.0
@export_range(1.0, 30.0, 0.1, "suffix:m") var depth: float = 10.0

func ensure_images_loaded() -> void:
	pass

func get_world_rectangle() -> Rect2:
	var half: float = radius * scale * 1.1
	return Rect2(
		Vector2(world_position.x - half, world_position.z - half),
		Vector2(half * 2.0, half * 2.0),
	)

func overlaps_chunk(chunk_world_rectangle: Rect2) -> bool:
	return get_world_rectangle().intersects(chunk_world_rectangle)

func sample_at_world(world_x: float, world_z: float) -> Vector2:
	var dx: float = world_x - world_position.x
	var dz: float = world_z - world_position.z
	var scaled_radius: float = radius * scale
	var scaled_depth: float = depth * scale

	# Single gentle lobe so the outline is an organic oval, not a perfect circle
	# and not a scalloped star. Y rotation turns the lobe per instance.
	var angle: float = atan2(dz, dx) - deg_to_rad(rotation_degrees)
	var warp: float = sin(angle * 2.0 + 0.6) * 0.04
	var r: float = sqrt(dx * dx + dz * dz) / scaled_radius + warp

	if r >= 1.0:
		return Vector2.ZERO

	var height: float = 0.0
	if r < FLOOR_EDGE:
		height = -scaled_depth
	else:
		# Steep wall, but smoothstep rounds the floor and ground corners so the
		# rim doesn't facet against the terrain grid. Steepest at mid-wall.
		var t: float = (r - FLOOR_EDGE) / (1.0 - FLOOR_EDGE)
		height = -scaled_depth * (1.0 - smoothstep(0.0, 1.0, t))

	# Gentle floor variance, faded out before the wall so the slope stays clean.
	var floor_weight: float = clampf((FLOOR_EDGE - r) / FLOOR_EDGE, 0.0, 1.0)
	height += _undulation(dx, dz) * scaled_depth * 0.05 * floor_weight

	# Feather influence to zero over the outer 10% so it blends into the terrain.
	var alpha: float = clampf((1.0 - r) / 0.1, 0.0, 1.0)
	return Vector2(height, alpha)

## Large smooth swells only — periods of ~140-200m, well wider than any crater,
## so the floor undulates without high-frequency ridges.
static func _undulation(x: float, z: float) -> float:
	return (
		sin(x * 0.045 + z * 0.03 + 0.7) +
		sin(x * 0.03 - z * 0.05 + 1.9) * 0.6
	) / 1.6
