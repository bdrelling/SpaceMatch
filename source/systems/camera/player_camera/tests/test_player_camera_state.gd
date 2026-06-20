extends GdUnitTestSuite
## Regression: trackpad pan gestures (and macOS flick momentum, which arrives as
## further pan gestures) used to rotate the spring arm at event time, while the
## camera only samples on the physics tick — uneven event-to-tick arrival showed
## as velocity stutter. Pan input now queues and drains smoothly per tick.

const PLAYER_CAMERA_SCENE: String = "res://systems/camera/player_camera/player_camera.tscn"
const TICK: float = 1.0 / 60.0

func _spawn_orbit_camera() -> PlayerCamera:
	var camera: PlayerCamera = (load(PLAYER_CAMERA_SCENE) as PackedScene).instantiate() as PlayerCamera
	camera.lock_mode = true
	camera.mode = PlayerCamera.Mode.ORBIT
	add_child(camera)
	return camera

func _current_state(camera: PlayerCamera) -> PlayerCameraState:
	return (camera.get_node("%Controller") as StateMachine).current_state as PlayerCameraState

func _pan_gesture(delta: Vector2) -> InputEventPanGesture:
	var gesture: InputEventPanGesture = InputEventPanGesture.new()
	gesture.delta = delta
	return gesture

func _free_camera(camera: PlayerCamera) -> void:
	camera.queue_free()
	await await_idle_frame()

func test_pan_settles_to_total_input() -> void:
	var camera: PlayerCamera = _spawn_orbit_camera()
	for frame: int in range(5):
		await await_idle_frame()
	var state: PlayerCameraState = _current_state(camera)
	var start: Vector3 = camera.phantom_camera.get_third_person_rotation_degrees()
	# 10 gesture events (a swipe plus its momentum tail), then let the drain empty.
	for event: int in range(10):
		state.handle_input(_pan_gesture(Vector2(0.5, 0.25)))
	for tick: int in range(120):
		state.physics_update(TICK)
	var scale: float = camera.mouse_sensitivity * camera.trackpad_sensitivity
	var end: Vector3 = camera.phantom_camera.get_third_person_rotation_degrees()
	await _free_camera(camera)
	assert_float(end.y).is_equal_approx(wrapf(start.y + 10 * 0.5 * scale, 0.0, 360.0), 0.05)
	assert_float(end.x).is_equal_approx(start.x + 10 * 0.25 * scale, 0.05)

func test_pan_spreads_over_multiple_ticks() -> void:
	var camera: PlayerCamera = _spawn_orbit_camera()
	for frame: int in range(5):
		await await_idle_frame()
	var state: PlayerCameraState = _current_state(camera)
	var start_yaw: float = camera.phantom_camera.get_third_person_rotation_degrees().y
	var total: float = 2.0 * camera.mouse_sensitivity * camera.trackpad_sensitivity
	state.handle_input(_pan_gesture(Vector2(2.0, 0.0)))
	state.physics_update(TICK)
	var applied: float = wrapf(camera.phantom_camera.get_third_person_rotation_degrees().y - start_yaw, -180.0, 180.0)
	await _free_camera(camera)
	# One tick spends only a fraction of the backlog — instant application is the regression.
	assert_float(applied).is_greater(0.0)
	assert_float(applied).is_less(total * 0.5)

func test_bursty_events_still_advance_every_tick() -> void:
	var camera: PlayerCamera = _spawn_orbit_camera()
	for frame: int in range(5):
		await await_idle_frame()
	var state: PlayerCameraState = _current_state(camera)
	# Events land on even ticks only (the event-clock/physics-clock beat); the
	# drain must keep the camera moving through the event-less ticks too.
	var previous_yaw: float = camera.phantom_camera.get_third_person_rotation_degrees().y
	var steps: Array[float] = []
	for tick: int in range(8):
		if tick % 2 == 0:
			state.handle_input(_pan_gesture(Vector2(1.0, 0.0)))
		state.physics_update(TICK)
		var yaw: float = camera.phantom_camera.get_third_person_rotation_degrees().y
		steps.append(wrapf(yaw - previous_yaw, -180.0, 180.0))
		previous_yaw = yaw
	await _free_camera(camera)
	for step: float in steps:
		assert_float(step).is_greater(0.01)
