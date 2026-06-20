extends PlayerCameraState
## Racing follow-cam: trails the target's heading on its own (no orbit input),
## widens the FOV with speed, and slides the follow point ahead along the travel
## direction so the camera reads the line, not the rider.

## How quickly the FOV eases toward its speed-scaled target.
const FOV_SMOOTHING: float = 4.0

var _base_fov: float = 0.0
var _base_follow_offset: Vector3 = Vector3.ZERO

func enter(_previous_state_name: StringName) -> void:
	_base_fov = camera.get_camera_3d().fov
	_base_follow_offset = camera.follow_offset

## Hand back the lens and follow point exactly as found, so switching modes
## mid-session leaves no racing residue.
func exit() -> void:
	camera.get_camera_3d().fov = _base_fov
	camera.phantom_camera.follow_offset = _base_follow_offset

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	_handle_chase(delta)
	var body: CharacterBody3D = camera.follow_target as CharacterBody3D
	if body == null:
		return
	var horizontal: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed_factor: float = clampf(horizontal.length() / camera.downhill_fov_full_speed, 0.0, 1.0)

	var camera_3d: Camera3D = camera.get_camera_3d()
	var target_fov: float = lerpf(_base_fov, camera.downhill_fov_max_degrees, speed_factor)
	camera_3d.fov = lerpf(camera_3d.fov, target_fov, clampf(FOV_SMOOTHING * delta, 0.0, 1.0))

	# The phantom camera's follow damping smooths the offset shift into a glide.
	var lookahead: Vector3 = Vector3.ZERO
	if horizontal.length() > 0.01:
		lookahead = horizontal.normalized() * camera.downhill_lookahead * speed_factor
	camera.phantom_camera.follow_offset = _base_follow_offset + lookahead
