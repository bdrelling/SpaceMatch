@tool
class_name TerrainStampData
extends Resource
## Sub-chunk authored heightmap that gets blended into procedurally-filled
## Terrain3D chunks at a fixed world position. The artist provides absolute
## height samples (seed-independent) plus an alpha mask; the runtime stamp
## pass lerps `procedural_height` toward `height_image.r` weighted by
## `alpha_image.r`, so the stamp's interior overrides procedural terrain
## while a feathered alpha boundary blends cleanly into whatever noise is
## around it.
##
## Image source: either drop pre-loaded `Image` instances onto `height_image`
## / `alpha_image` directly, OR set `*_image_path` to a `res://` EXR/PNG and
## the runtime will `load()` it on first sample. The path's source file must be
## imported with the **Image** importer (Import As: Image) so `load()` returns
## an `Image` rather than a `CompressedTexture2D`; this is what makes the path
## option work on export. The crash-crater demo wants seed-independent absolute
## floats (EXR), so the height map ships as an Image resource, not a texture.
##
## Pixel layout: the stamp is centered on `world_position`. A stamp of
## `world_size` (32, 32) anchored at world (0, 0, 0) covers world XZ in
## the box (-16..16, -16..16). Pixel (0, 0) of the image samples the
## south-west corner; pixel (width-1, height-1) samples the north-east.

## Absolute heightmap in meters. R channel sampled. FORMAT_RF or FORMAT_R8
## both work; FORMAT_RF preserves precision for tall structures and signed
## negative depths (craters).
@export var height_image: Image

## Alpha mask for the blend. R channel sampled; 1.0 = stamp wins, 0.0 =
## procedural wins. Width/height must match `height_image`. If left null,
## the stamp applies at full strength inside its footprint with no
## feathering — useful for tests but visible as a hard seam in-game.
@export var alpha_image: Image

## Optional `res://` path to a height EXR/PNG. Loaded lazily via
## `Image.load()` if `height_image` is null when the runtime samples this
## stamp. Leave blank if `height_image` is already assigned.
@export_file("*.exr", "*.png") var height_image_path: String = ""

## Optional `res://` path to an alpha EXR/PNG. Loaded lazily the same way
## as `height_image_path`.
@export_file("*.exr", "*.png") var alpha_image_path: String = ""

## World-space center of the stamp's footprint. Y is ignored — heights are
## absolute and come straight from `height_image`.
@export var world_position: Vector3 = Vector3.ZERO

## World-space size of the stamp's footprint in meters (XZ). The image
## resolution can differ from this; we resample via nearest-neighbour at
## runtime.
@export var world_size: Vector2 = Vector2(32.0, 32.0)

## Y-axis rotation applied at sample time (degrees). The stamp image rotates
## around its center. `get_world_rectangle` returns the expanded AABB that fits the
## rotated footprint so no chunk overlap check is missed.
@export_range(-180.0, 180.0, 0.5, "degrees") var rotation_degrees: float = 0.0

## Uniform scale multiplier applied at sample time. Values > 1 enlarge the
## sampled footprint; < 1 shrink it. `world_size` is not changed — only the
## sampling transform is scaled.
@export_range(0.1, 10.0, 0.01) var scale: float = 1.0

## Idempotent: if `height_image` / `alpha_image` aren't assigned but their
## `*_image_path` fields are, load them once and cache. Called by the
## runtime before sampling. Safe to call repeatedly.
func ensure_images_loaded() -> void:
	if height_image == null and not height_image_path.is_empty():
		var loaded_height: Image = load(height_image_path) as Image
		if loaded_height != null:
			height_image = loaded_height
		else:
			push_error("TerrainStampData: failed to load height image '%s' (is it imported as Image?)" % height_image_path)
	if alpha_image == null and not alpha_image_path.is_empty():
		var loaded_alpha: Image = load(alpha_image_path) as Image
		if loaded_alpha != null:
			alpha_image = loaded_alpha
		else:
			push_error("TerrainStampData: failed to load alpha image '%s' (is it imported as Image?)" % alpha_image_path)

## Axis-aligned bounding rect this stamp covers in world XZ. Accounts for
## rotation and scale so chunk overlap checks never miss a rotated footprint.
func get_world_rectangle() -> Rect2:
	var orig_hw: float = world_size.x * 0.5 * scale
	var orig_hh: float = world_size.y * 0.5 * scale
	var aabb_hw: float = orig_hw
	var aabb_hh: float = orig_hh
	if not is_zero_approx(rotation_degrees):
		var radians: float = deg_to_rad(rotation_degrees)
		var abs_cos: float = absf(cos(radians))
		var abs_sin: float = absf(sin(radians))
		aabb_hw = abs_cos * orig_hw + abs_sin * orig_hh
		aabb_hh = abs_sin * orig_hw + abs_cos * orig_hh
	return Rect2(
		Vector2(world_position.x - aabb_hw, world_position.z - aabb_hh),
		Vector2(aabb_hw * 2.0, aabb_hh * 2.0),
	)

## True if this stamp's footprint overlaps the given chunk rect.
func overlaps_chunk(chunk_world_rectangle: Rect2) -> bool:
	return get_world_rectangle().intersects(chunk_world_rectangle)

## Sample the stamp at a world-space XZ point. Returns Vector2(height, alpha).
## Caller is responsible for first calling `ensure_images_loaded` and
## `overlaps_chunk`. Nearest-neighbour resample.
func sample_at_world(world_x: float, world_z: float) -> Vector2:
	if height_image == null:
		return Vector2.ZERO
	var image_size: Vector2i = height_image.get_size()
	if image_size.x <= 0 or image_size.y <= 0 or world_size.x <= 0.0 or world_size.y <= 0.0:
		return Vector2.ZERO
	var offset_x: float = world_x - world_position.x
	var offset_z: float = world_z - world_position.z
	if not is_zero_approx(rotation_degrees):
		var radians: float = -deg_to_rad(rotation_degrees)
		var rotated_x: float = offset_x * cos(radians) - offset_z * sin(radians)
		var rotated_z: float = offset_x * sin(radians) + offset_z * cos(radians)
		offset_x = rotated_x
		offset_z = rotated_z
	if not is_equal_approx(scale, 1.0) and scale > 0.0:
		offset_x /= scale
		offset_z /= scale
	var u: float = (offset_x / world_size.x) + 0.5
	var v: float = (offset_z / world_size.y) + 0.5
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2.ZERO
	var pixel_x: int = clampi(int(u * float(image_size.x)), 0, image_size.x - 1)
	var pixel_y: int = clampi(int(v * float(image_size.y)), 0, image_size.y - 1)
	var height: float = height_image.get_pixel(pixel_x, pixel_y).r
	var alpha: float = 1.0
	if alpha_image != null:
		var alpha_size: Vector2i = alpha_image.get_size()
		if alpha_size.x > 0 and alpha_size.y > 0:
			var alpha_x: int = clampi(int(u * float(alpha_size.x)), 0, alpha_size.x - 1)
			var alpha_y: int = clampi(int(v * float(alpha_size.y)), 0, alpha_size.y - 1)
			alpha = alpha_image.get_pixel(alpha_x, alpha_y).r
	return Vector2(height, alpha)
