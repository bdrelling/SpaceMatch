class_name RustboardPhysics
extends RefCounted
## Applies rustboard movement physics to a CharacterBody3D.
##
## Near-stateless helper — mutable state lives on the body's velocity, plus the
## previous floor normal kept on the board (see [member Rustboard.last_floor_normal]).
## Call [method apply_with_nudge] once per physics frame; the caller supplies the player's
## nudge and jump input, so this helper stays free of any input or player-class dependency.
##
## Reads tuning off the [Rustboard]'s own copied fields, never its blueprint.
##
## Friction is Coulomb (dry) friction, not a proportional drag: a constant
## deceleration that brings the board to a genuine stop, plus a static grip that
## holds it in place on slopes shallower than atan(static / slope_scale). That
## gives the snowboard feel — glide downhill, decelerate up the far side, stop at
## the crest, and roll back down when the slope is steep enough to break grip.
##
## Grounded velocity lives in the floor plane, not the horizontal plane: speed
## up a wall is genuinely vertical momentum, so cresting a lip launches the
## board into the air instead of flattening the climb away, and landing absorbs
## only the into-the-floor component of the fall.

## Radians the floor normal may swing per physics frame before the board stops
## following the surface and launches — following a sharper convex corner would
## bend the path around the edge and absorb the speed. The ~12° window sits
## above the few degrees of facet-to-facet jitter a terrain mesh produces (must
## never shake the board loose) and below the ~20°/frame the contact normal
## sweeps as the capsule rolls over a real lip at speed.
const DETACH_ANGLE: float = 0.21

static func apply_with_nudge(
	body: CharacterBody3D,
	board: Rustboard,
	gravity: float,
	terminal_velocity: float,
	delta: float,
	nudge_input: float,
	jump_pressed: bool,
	jump_velocity: float,
) -> void:
	var grounded: bool = body.is_on_floor()
	if grounded and _should_detach(body, board):
		grounded = false
	if grounded:
		_apply_ground(body, board, gravity, nudge_input, delta)
		if jump_pressed:
			# Kick off along the surface, not world-up — jumping off a wall pushes
			# away from the wall. Identical to the old straight-up jump on flat ground.
			body.velocity += body.get_floor_normal() * jump_velocity
		var planned_velocity: Vector3 = body.velocity
		body.move_and_slide()
		# Plane velocity points against gravity on any climb, which move_and_slide
		# reads as a jump — it skips floor snap and drops contact every frame. Re-stick
		# while a floor is still within snap reach; a genuine lip launch moves the
		# floor out of reach within a frame or two and stays airborne.
		if not jump_pressed and not body.is_on_floor():
			body.apply_floor_snap()
		# And on descent move_and_slide flattens velocity to the horizontal every
		# frame (it strips the downhill -y as if it were gravity buildup), which
		# bleeds a plane velocity down to a crawl. Restore what ground physics
		# computed unless a wall genuinely redirected the body.
		if body.is_on_floor() and not body.is_on_wall() and not jump_pressed:
			body.velocity = planned_velocity
	else:
		board.last_floor_normal = Vector3.ZERO
		board.smoothed_floor_normal = Vector3.ZERO
		body.velocity.y -= gravity * delta
		body.velocity.y = maxf(body.velocity.y, terminal_velocity)
		_clamp_horizontal_speed(body, board)
		body.move_and_slide()

## True when the floor has rotated away from under the board since last frame —
## a convex corner crossed with speed. The signal is the per-frame swing of the
## floor normal, never velocity vs. normal: move_and_slide flattens grounded
## velocity to the horizontal at will, which would read as permanently "leaving"
## any slope steeper than the detach angle.
static func _should_detach(body: CharacterBody3D, board: Rustboard) -> bool:
	var normal: Vector3 = body.get_floor_normal()
	var previous_normal: Vector3 = board.last_floor_normal
	board.last_floor_normal = normal
	if previous_normal == Vector3.ZERO:
		return false
	if previous_normal.angle_to(normal) <= DETACH_ANGLE:
		return false
	# Concave turns rotate the floor *into* the travel direction and keep riding;
	# only a floor rotating away (convex) throws the board.
	return body.velocity.dot(normal - previous_normal) > 0.0

## Body-local rotation that aligns the rider's up axis to [param local_normal]
## while keeping the board pointed along the body's forward axis. Feed it the
## floor normal rotated into the body's local space; identity when the normal
## is (near-)parallel to forward, which [member CharacterBody3D.floor_max_angle]
## keeps out of reach in practice.
static func tilt_for_normal(local_normal: Vector3) -> Quaternion:
	var up: Vector3 = local_normal.normalized()
	var forward: Vector3 = Vector3.FORWARD - up * Vector3.FORWARD.dot(up)
	if forward.length_squared() < 0.000001:
		return Quaternion.IDENTITY
	forward = forward.normalized()
	var back: Vector3 = -forward
	return Basis(up.cross(back), up, back).orthonormalized().get_rotation_quaternion()

static func _apply_ground(
	body: CharacterBody3D,
	board: Rustboard,
	gravity: float,
	nudge_input: float,
	delta: float,
) -> void:
	var normal: Vector3 = body.get_floor_normal()
	# Slope acceleration reads a smoothed normal when configured; contact
	# projection, carve, and detach always use the raw one.
	var pull_normal: Vector3 = _pull_normal(body, board, delta)
	var cos_theta: float = clampf(pull_normal.dot(Vector3.UP), 0.001, 1.0)
	# Gravity's pull within the floor plane: zero on flat ground, length sin(θ)
	# on a slope, pointing straight down the fall line.
	var slope_pull: Vector3 = Vector3.DOWN - pull_normal * Vector3.DOWN.dot(pull_normal)
	var sin_theta: float = slope_pull.length()
	var slope_direction: Vector3 = slope_pull / sin_theta if sin_theta > 0.0001 else Vector3.ZERO

	# Work in the floor plane: keep only the velocity sliding along the surface
	# (landing impact is absorbed here), and run the board's forward axis along it.
	var velocity: Vector3 = body.velocity - normal * body.velocity.dot(normal)
	var forward: Vector3 = -body.transform.basis.z
	forward = (forward - normal * forward.dot(normal)).normalized()

	var slope_acceleration: float = gravity * sin_theta * board.slope_acceleration_scale

	# Static friction: at rest, no input, and the slope can't break grip → hold.
	var grip: float = gravity * cos_theta * board.static_friction
	if velocity.length() < board.stop_speed and is_zero_approx(nudge_input) and slope_acceleration <= grip:
		body.velocity = Vector3.ZERO
		return

	# Gravity along the slope (downhill) + the player's forward/back nudge.
	velocity += slope_direction * slope_acceleration * delta
	velocity += forward * nudge_input * board.nudge_acceleration * delta

	# Carve: swing the velocity to follow the board's heading without losing
	# speed — rails, not drift. The nearer end leads, so switch stays switch.
	if board.carve_grip > 0.0:
		var speed: float = velocity.length()
		if speed > 0.001:
			var heading: Vector3 = forward if velocity.dot(forward) >= 0.0 else -forward
			var direction: Vector3 = velocity / speed
			var turn: float = direction.signed_angle_to(heading, normal)
			turn = clampf(turn, -board.carve_grip * delta, board.carve_grip * delta)
			velocity = direction.rotated(normal, turn) * speed

	# Split into along-board and sideways: the board glides forward but grips
	# sideways, so it carves instead of skidding off its edge.
	var forward_speed: float = velocity.dot(forward)
	var lateral_component: Vector3 = velocity - forward * forward_speed

	# Forward: Coulomb kinetic friction — constant decel toward a full stop.
	var kinetic_deceleration: float = gravity * cos_theta * board.kinetic_friction * delta
	forward_speed = move_toward(forward_speed, 0.0, kinetic_deceleration)

	# Sideways: strong proportional grip.
	lateral_component *= maxf(0.0, 1.0 - board.lateral_friction * delta)

	velocity = forward * forward_speed + lateral_component
	if velocity.length() > board.max_speed:
		velocity = velocity.normalized() * board.max_speed
	body.velocity = velocity

## The normal the slope pull reads: the raw contact normal, or a trailing blend
## of it when [member Rustboard.normal_smoothing] is configured — faceted
## terrain then pulls evenly instead of ticking seam to seam.
static func _pull_normal(body: CharacterBody3D, board: Rustboard, delta: float) -> Vector3:
	var normal: Vector3 = body.get_floor_normal()
	if board.normal_smoothing <= 0.0:
		return normal
	if board.smoothed_floor_normal == Vector3.ZERO:
		board.smoothed_floor_normal = normal
	else:
		board.smoothed_floor_normal = board.smoothed_floor_normal.slerp(
			normal, clampf(board.normal_smoothing * delta, 0.0, 1.0)
		).normalized()
	return board.smoothed_floor_normal

static func _clamp_horizontal_speed(
	body: CharacterBody3D,
	board: Rustboard,
) -> void:
	var horizontal: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	if horizontal.length() > board.max_speed:
		var clamped: Vector3 = horizontal.normalized() * board.max_speed
		body.velocity.x = clamped.x
		body.velocity.z = clamped.z
