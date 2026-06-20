extends SceneTree
## Generates the outpost flattening stamp: a height=0 plane with a feathered
## alpha mask that blends from fully flat at center to fully procedural at
## edges. Run headless:
##
##     godot --headless --script res://systems/world/terrain/bake_outpost_stamp.gd

const RESOLUTION: int = 256
const FLAT_HALF_SIZE: float = 64.0
const BLEND_MARGIN: float = 32.0

func _init() -> void:
	var total_half: float = FLAT_HALF_SIZE + BLEND_MARGIN
	var height_image: Image = Image.create_empty(RESOLUTION, RESOLUTION, false, Image.FORMAT_RF)
	height_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	var alpha_image: Image = Image.create_empty(RESOLUTION, RESOLUTION, false, Image.FORMAT_RF)
	for pixel_y: int in range(RESOLUTION):
		for pixel_x: int in range(RESOLUTION):
			var world_x: float = (float(pixel_x) / float(RESOLUTION - 1) - 0.5) * 2.0 * total_half
			var world_z: float = (float(pixel_y) / float(RESOLUTION - 1) - 0.5) * 2.0 * total_half
			var d: float = sqrt(world_x * world_x + world_z * world_z)
			var alpha: float = 0.0
			if d <= FLAT_HALF_SIZE:
				alpha = 1.0
			elif d <= total_half:
				var t: float = (d - FLAT_HALF_SIZE) / BLEND_MARGIN
				alpha = 1.0 - t * t * (3.0 - 2.0 * t)
			alpha_image.set_pixel(pixel_x, pixel_y, Color(alpha, 0.0, 0.0, 1.0))
	var world_size: float = total_half * 2.0
	var height_path: String = "res://systems/world/terrain/stamps/outpost_flat_height.exr"
	var alpha_path: String = "res://systems/world/terrain/stamps/outpost_flat_alpha.exr"
	var height_error: int = height_image.save_exr(height_path, false)
	var alpha_error: int = alpha_image.save_exr(alpha_path, false)
	print("[bake_outpost_stamp] height save: ", error_string(height_error), " → ", height_path)
	print("[bake_outpost_stamp] alpha save:  ", error_string(alpha_error), " → ", alpha_path)
	print("[bake_outpost_stamp] world_size = Vector2(%s, %s)" % [world_size, world_size])
	quit(0)
