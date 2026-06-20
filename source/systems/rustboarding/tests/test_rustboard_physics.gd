extends GdUnitTestSuite
## Covers [method RustboardPhysics.tilt_for_normal] — the returned rotation maps
## up onto the floor normal, keeps forward in the body's forward plane, and
## degrades to identity on flat ground or a degenerate normal — and
## [method RustboardPhysics.apply_with_nudge]'s floor handling on slopes.

## Drives [method RustboardPhysics.apply_with_nudge] each physics frame and
## counts floor contact, so a test can detect the board flickering airborne.
class SlopeDriver:
	extends CharacterBody3D

	var board: Rustboard
	var frames_total: int = 0
	var frames_on_floor: int = 0
	var launched: bool = false
	var launch_velocity_y: float = 0.0
	var trace: Array[String] = []
	var _was_on_floor: bool = false

	func _physics_process(delta: float) -> void:
		RustboardPhysics.apply_with_nudge(self, board, 9.8, -50.0, delta, 0.0, false, 9.0)
		frames_total += 1
		if is_on_floor():
			frames_on_floor += 1
		if _was_on_floor != is_on_floor() and trace.size() < 12:
			trace.append("f%d %s v=%v p=%v" % [
				frames_total, "air" if _was_on_floor else "land", velocity, position,
			])
		if _was_on_floor and not is_on_floor() and not launched:
			launched = true
			launch_velocity_y = velocity.y
		_was_on_floor = is_on_floor()

var _runner: GdUnitSceneRunner

func _build_driver(start_position: Vector3) -> SlopeDriver:
	var driver := SlopeDriver.new()
	var driver_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	driver_shape.shape = capsule
	driver_shape.position.y = 0.8
	driver.add_child(driver_shape)
	driver.floor_snap_length = 0.6
	driver.floor_max_angle = 1.3089969
	driver.position = start_position
	driver.board = auto_free(Rustboard.new())
	return driver

## A box slope segment whose top surface starts at [param top_start] and runs
## [param length] downhill (+Z descending). Returns the surface end point, so
## segments can be chained into a faceted slope.
func _add_slope_box(root: Node3D, angle: float, top_start: Vector3, length: float) -> Vector3:
	var downhill: Vector3 = Vector3(0.0, -sin(angle), cos(angle))
	var normal: Vector3 = Vector3(0.0, cos(angle), sin(angle))
	var slope := StaticBody3D.new()
	var slope_shape := CollisionShape3D.new()
	var slope_box := BoxShape3D.new()
	slope_box.size = Vector3(60.0, 1.0, length + 0.05)
	slope_shape.shape = slope_box
	slope.add_child(slope_shape)
	slope.rotation.x = angle
	slope.position = top_start + downhill * (length / 2.0) - normal * 0.5
	root.add_child(slope)
	return top_start + downhill * length

## Builds a single-slope rig: an [param angle]-radian box slope whose surface
## passes through the origin (lip at 30 along the up-slope, which runs -Z) and a
## [SlopeDriver] dropped onto it at [param start_position].
func _build_slope_rig(angle: float, start_position: Vector3) -> SlopeDriver:
	var root: Node3D = auto_free(Node3D.new())
	var uphill: Vector3 = Vector3(0.0, sin(angle), -cos(angle))
	_add_slope_box(root, angle, uphill * 30.0, 60.0)
	var driver: SlopeDriver = _build_driver(start_position)
	root.add_child(driver)
	_runner = scene_runner(root)
	return driver

## Builds two chained slope segments meeting at a convex junction — the faceted
## shape a terrain mesh hands the board at every triangle seam.
func _build_two_segment_rig(first_angle: float, second_angle: float, segment_length: float) -> SlopeDriver:
	var root: Node3D = auto_free(Node3D.new())
	var junction: Vector3 = _add_slope_box(root, first_angle, Vector3.ZERO, segment_length)
	_add_slope_box(root, second_angle, junction, segment_length)
	var driver: SlopeDriver = _build_driver(Vector3(0.0, 0.1, 0.0))
	root.add_child(driver)
	_runner = scene_runner(root)
	return driver

## Settles the driver onto the slope, stopping as soon as contact is made — a
## 20° slope breaks static grip, so every extra settled frame slides the board
## down-slope away from where the test placed it.
func _settle_onto_floor(driver: SlopeDriver) -> void:
	for i: int in 30:
		await _runner.simulate_frames(5)
		if driver.is_on_floor():
			return

func test_up_slope_travel_keeps_floor_contact() -> void:
	# Riding up an incline gives the plane velocity an upward component, which
	# move_and_slide reads as a jump and answers by dropping floor snap. The board
	# must stay grounded the whole climb, not flicker between floor and air.
	var angle: float = deg_to_rad(20.0)
	var driver: SlopeDriver = _build_slope_rig(angle, Vector3(0.0, 0.1, 0.0))
	await _settle_onto_floor(driver)
	assert_bool(driver.is_on_floor()).is_true()

	# Send the board up the slope along the surface plane.
	driver.velocity = Vector3(0.0, sin(angle), -cos(angle)) * 8.0
	driver.frames_total = 0
	driver.frames_on_floor = 0
	await _runner.simulate_frames(60)
	assert_int(driver.frames_total).is_greater_equal(10)
	assert_int(driver.frames_on_floor).is_greater_equal(driver.frames_total - 2)

func test_downhill_glide_gains_speed() -> void:
	# From rest on a slope steep enough to break grip, gravity along the surface
	# must build real riding speed — the downhill run is the core of the feel.
	var angle: float = deg_to_rad(20.0)
	var driver: SlopeDriver = _build_slope_rig(angle, Vector3(0.0, 0.1, 0.0))
	await _settle_onto_floor(driver)
	assert_bool(driver.is_on_floor()).is_true()

	driver.velocity = Vector3.ZERO
	await _runner.simulate_frames(120)
	assert_float(driver.velocity.length()).is_greater(3.0)

func test_convex_facet_junction_keeps_floor_contact() -> void:
	# A terrain mesh hands the board small convex normal jumps at every triangle
	# seam; crossing one at speed must not read as a lip — the board stays glued,
	# keeps accelerating, and keeps the grip that steering is made of.
	var first_angle: float = deg_to_rad(20.0)
	var driver: SlopeDriver = _build_two_segment_rig(first_angle, deg_to_rad(30.0), 12.0)
	await _settle_onto_floor(driver)
	assert_bool(driver.is_on_floor()).is_true()

	driver.velocity = Vector3(0.0, -sin(first_angle), cos(first_angle)) * 12.0
	driver.frames_total = 0
	driver.frames_on_floor = 0
	await _runner.simulate_frames(180)
	assert_int(driver.frames_total).is_greater_equal(10)
	assert_int(driver.frames_on_floor).is_greater_equal(driver.frames_total - 2)
	assert_float(driver.velocity.length()).is_greater(12.0)

func test_flat_carve_redirects_velocity_to_forward() -> void:
	# Carving is how steering is felt: sideways velocity drains into the board's
	# forward axis instead of skidding, so a yawed board swings its travel around.
	var driver: SlopeDriver = _build_slope_rig(0.0, Vector3(0.0, 0.1, 0.0))
	await _settle_onto_floor(driver)
	assert_bool(driver.is_on_floor()).is_true()

	driver.velocity = Vector3(4.5, 0.0, -4.5)
	await _runner.simulate_frames(90)
	assert_float(absf(driver.velocity.x)).is_less(0.6)
	assert_float(-driver.velocity.z).is_greater(2.5)

func test_cresting_the_lip_launches_airborne() -> void:
	# The re-stick snap must not glue the board down where the slope ends: carrying
	# speed off the lip has to convert into a real launch with upward momentum.
	var angle: float = deg_to_rad(20.0)
	# Start 24 of the 30 up-slope units toward the lip, just above the surface.
	var start: Vector3 = Vector3(0.0, sin(angle), -cos(angle)) * 24.0 + Vector3(0.0, 0.1, 0.0)
	var driver: SlopeDriver = _build_slope_rig(angle, start)
	await _settle_onto_floor(driver)
	assert_bool(driver.is_on_floor()).is_true()

	driver.velocity = Vector3(0.0, sin(angle), -cos(angle)) * 12.0
	driver.launched = false
	var start_position: Vector3 = driver.position
	await _runner.simulate_frames(180)
	assert_bool(driver.launched) \
		.override_failure_message("no launch: start=%s end=%s velocity=%s on_floor=%s frames=%d" % [
			start_position, driver.position, driver.velocity, driver.is_on_floor(), driver.frames_total,
		]) \
		.is_true()
	assert_float(driver.launch_velocity_y) \
		.override_failure_message("transitions: " + " | ".join(driver.trace)) \
		.is_greater(1.0)

func test_flat_floor_is_identity() -> void:
	var tilt: Quaternion = RustboardPhysics.tilt_for_normal(Vector3.UP)
	assert_bool(tilt.is_equal_approx(Quaternion.IDENTITY)).is_true()

func test_up_axis_maps_to_normal() -> void:
	var normal: Vector3 = Vector3(0.0, 1.0, 1.0).normalized()
	var tilt: Quaternion = RustboardPhysics.tilt_for_normal(normal)
	assert_bool((tilt * Vector3.UP).is_equal_approx(normal)).is_true()

func test_forward_stays_in_forward_plane() -> void:
	# Pitching up a slope must not introduce any sideways lean.
	var normal: Vector3 = Vector3(0.0, 1.0, 1.0).normalized()
	var tilt: Quaternion = RustboardPhysics.tilt_for_normal(normal)
	var tilted_forward: Vector3 = tilt * Vector3.FORWARD
	assert_float(tilted_forward.x).is_equal_approx(0.0, 0.000001)
	assert_float(tilted_forward.dot(Vector3.FORWARD)).is_greater(0.0)

func test_sideways_normal_rolls_without_turning() -> void:
	# A wall to the rider's side banks the board but leaves its heading alone.
	var normal: Vector3 = Vector3(1.0, 1.0, 0.0).normalized()
	var tilt: Quaternion = RustboardPhysics.tilt_for_normal(normal)
	assert_bool((tilt * Vector3.UP).is_equal_approx(normal)).is_true()
	assert_bool((tilt * Vector3.FORWARD).is_equal_approx(Vector3.FORWARD)).is_true()

func test_normal_parallel_to_forward_is_identity() -> void:
	var tilt: Quaternion = RustboardPhysics.tilt_for_normal(Vector3.FORWARD)
	assert_bool(tilt.is_equal_approx(Quaternion.IDENTITY)).is_true()

func test_carve_grip_turns_without_speed_loss() -> void:
	# With carve grip, sideways velocity swings to follow the heading instead of
	# being damped away — the turn keeps its speed (rails, not drift).
	var driver: SlopeDriver = _build_slope_rig(0.0, Vector3(0.0, 0.1, 0.0))
	driver.board.carve_grip = 5.0
	driver.board.lateral_friction = 0.0
	await _settle_onto_floor(driver)
	assert_bool(driver.is_on_floor()).is_true()

	driver.velocity = Vector3(4.5, 0.0, -4.5)
	await _runner.simulate_frames(90)
	assert_float(absf(driver.velocity.x)).is_less(0.6)
	assert_float(driver.velocity.length()).is_greater(5.0)
