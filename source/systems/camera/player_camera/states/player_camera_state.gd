class_name PlayerCameraState
extends State
## Base state for [PlayerCamera] behaviours.
##
## Holds the shared camera reference and the helpers every mode uses. Tilt input
## applies in every mode, so the base [method physics_update] runs it; concrete
## states call [code]super.physics_update(delta)[/code] first, then add their own
## per-frame work (orbit, chase, etc.).

const LOCKED_YAW: StringName = &"LockedYaw"
const ORBIT: StringName = &"Orbit"
const CHASE: StringName = &"Chase"
const ORBIT_AND_CHASE: StringName = &"OrbitAndChase"
const DOWNHILL_CHASE: StringName = &"DownhillChase"

var camera: PlayerCamera
var _yaw_panned: bool = false
var _scroll_velocity: float = 0.0
# Pan input queues here (pre-scaled degrees: x orbits yaw, y tilts pitch) instead
# of applying at event time: events tick on the input clock while the camera only
# samples on the physics tick, so per-event application aliases into per-tick
# velocity jitter — visible stutter during fast pans and trackpad momentum.
# _drain_pending_pan spends it smoothly on the physics clock.
var _pending_pan: Vector2 = Vector2.ZERO

# No await here: the owner applies its mode from its own _ready, which calls
# enter() on the target state before owner.ready ever fires — camera must
# already be set by then. owner is assigned before children enter the tree.
func _ready() -> void:
	camera = owner as PlayerCamera
	assert(camera != null)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and ManagedInput.is_action_pressed(camera.pan_action):
		_queue_pan((event as InputEventMouseMotion).relative * camera.mouse_pan_sign * camera.mouse_sensitivity)
	elif event is InputEventMouseButton and event.is_action_pressed(camera.tilt_up_action):
		_apply_scroll_tilt(1.0)
	elif event is InputEventMouseButton and event.is_action_pressed(camera.tilt_down_action):
		_apply_scroll_tilt(-1.0)
	elif event is InputEventPanGesture:
		# Two-finger trackpad drag: horizontal orbits the yaw, vertical tilts the
		# pitch, diagonal does both — the same pan the middle-mouse drag performs.
		# macOS streams its momentum (flick) phase as further pan gestures, so the
		# native inertial scroll arrives here too.
		_queue_pan((event as InputEventPanGesture).delta * camera.trackpad_pan_sign * camera.mouse_sensitivity * camera.trackpad_sensitivity)

func physics_update(delta: float) -> void:
	_handle_tilt_input(delta)
	_handle_scroll_inertia(delta)
	_drain_pending_pan(delta)

func _handle_tilt_input(delta: float) -> void:
	# TILT_UP/DOWN are bound to the scroll wheel; ManagedInput returns 0 while a UI
	# owns the mouse (or the window is unfocused), so scrolling a menu can't tilt.
	var axis: float = ManagedInput.get_axis(camera.tilt_down_action, camera.tilt_up_action)
	if Settings.game.invert_y_axis:
		axis = -axis
	if is_zero_approx(axis):
		return
	var current_degrees: Vector3 = camera.phantom_camera.get_third_person_rotation_degrees()
	current_degrees.x = clampf(
		current_degrees.x + axis * camera.tilt_speed_degrees * delta,
		PlayerCamera.PITCH_MIN,
		PlayerCamera.PITCH_MAX,
	)
	camera.phantom_camera.set_third_person_rotation_degrees(current_degrees)
	camera.phantom_camera.spring_length = PlayerCamera.spring_length_for_pitch(current_degrees.x)

## Returns [code]true[/code] when orbit input was applied this frame.
func _handle_orbit_input(delta: float) -> bool:
	var axis: float = ManagedInput.get_axis(camera.rotate_left_action, camera.rotate_right_action)
	if is_zero_approx(axis):
		return false
	var current_degrees: Vector3 = camera.phantom_camera.get_third_person_rotation_degrees()
	current_degrees.y += axis * camera.orbit_sign * camera.orbit_speed_degrees * delta
	current_degrees.y = wrapf(current_degrees.y, 0.0, 360.0)
	camera.phantom_camera.set_third_person_rotation_degrees(current_degrees)
	return true

func _apply_scroll_tilt(direction: float) -> void:
	if not is_instance_valid(camera):
		return
	_scroll_velocity += direction * camera.scroll_tilt_step * camera.scroll_friction

func _handle_scroll_inertia(delta: float) -> void:
	if is_zero_approx(_scroll_velocity):
		return
	_apply_tilt(_scroll_velocity * delta)
	_scroll_velocity *= exp(-camera.scroll_friction * delta)
	if absf(_scroll_velocity) < 0.1:
		_scroll_velocity = 0.0

func _apply_tilt(delta_degrees: float) -> void:
	if not is_instance_valid(camera):
		return
	var current_degrees: Vector3 = camera.phantom_camera.get_third_person_rotation_degrees()
	current_degrees.x = clampf(
		current_degrees.x + delta_degrees,
		PlayerCamera.PITCH_MIN,
		PlayerCamera.PITCH_MAX,
	)
	camera.phantom_camera.set_third_person_rotation_degrees(current_degrees)
	camera.phantom_camera.spring_length = PlayerCamera.spring_length_for_pitch(current_degrees.x)

func _queue_pan(delta_degrees: Vector2) -> void:
	_pending_pan += delta_degrees

## Spends the queued pan as an exponential drain: each tick applies a fixed
## fraction of the backlog, so uneven event-to-tick arrival is averaged over the
## filter window while the total applied rotation still equals the total input.
func _drain_pending_pan(delta: float) -> void:
	if not is_instance_valid(camera) or _pending_pan.is_zero_approx():
		return
	var step: Vector2 = _pending_pan * (1.0 - exp(-camera.pan_smoothing * delta))
	_pending_pan -= step
	if _pending_pan.length() < 0.01:
		step += _pending_pan
		_pending_pan = Vector2.ZERO
	_apply_pan(step)

## Applies a pan from an already-signed, already-scaled delta in degrees: +X orbits
## the yaw, +Y tilts the pitch. The caller bakes in the device's direction and
## sensitivity when queueing ([member PlayerCamera.mouse_pan_sign] /
## [member PlayerCamera.trackpad_pan_sign]), so this carries no hardcoded direction.
## Only horizontal motion flags a yaw-pan; tilt alone shouldn't stall chase-resume.
func _apply_pan(delta: Vector2) -> void:
	if not is_instance_valid(camera):
		return
	if not is_zero_approx(delta.x):
		var current_degrees: Vector3 = camera.phantom_camera.get_third_person_rotation_degrees()
		current_degrees.y += delta.x
		current_degrees.y = wrapf(current_degrees.y, 0.0, 360.0)
		camera.phantom_camera.set_third_person_rotation_degrees(current_degrees)
		_yaw_panned = true
	if not is_zero_approx(delta.y):
		_apply_tilt(delta.y)

func _handle_chase(delta: float) -> void:
	if not is_instance_valid(camera.follow_target):
		return
	var target_yaw: float = camera.follow_target.rotation.y
	var current: Vector3 = camera.phantom_camera.get_third_person_rotation()
	current.y = lerp_angle(current.y, target_yaw, camera.chase_smoothing * delta)
	camera.phantom_camera.set_third_person_rotation_degrees(
		Vector3(rad_to_deg(current.x), rad_to_deg(current.y), 0.0),
	)
