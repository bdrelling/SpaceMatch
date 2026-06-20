extends PlayerMovementState

func enter(_previous_state_name: StringName) -> void:
	player.rustboarding = true
	player.rustboard.steer_value = 0.0
	player.rustboard.deploy()
	player.dust_emitter.transition_to(&"Board")

func physics_update(delta: float) -> void:
	var board: Rustboard = player.rustboard
	var move_axis: float = get_move_axis()
	var strafe_axis: float = get_strafe_axis()
	var raw_input: Vector3 = Vector3(strafe_axis, 0.0, -move_axis)
	if raw_input.length_squared() > 1.0:
		raw_input = raw_input.normalized()
	var camera_basis: Basis = player.get_camera_yaw_basis()
	var world_direction: Vector3 = camera_basis * raw_input
	var board_forward: Vector3 = -player.transform.basis.z
	var board_right: Vector3 = player.transform.basis.x
	var steer_input: float = world_direction.dot(board_right)
	# Ramped steering: ease toward the stick instead of snapping, so carves
	# start progressively. Instant when no ramp is configured.
	if board.steer_ramp > 0.0:
		board.steer_value = move_toward(board.steer_value, steer_input, board.steer_ramp * delta)
	else:
		board.steer_value = steer_input
	if not is_zero_approx(board.steer_value):
		var turn_rate: float = board.rotation_speed
		if board.speed_turn_falloff > 0.0:
			# Wider arcs at speed: tight slalom handling at a crawl, sweeping
			# carves at full tilt.
			var horizontal_speed: float = Vector3(player.velocity.x, 0.0, player.velocity.z).length()
			turn_rate /= 1.0 + horizontal_speed * board.speed_turn_falloff
		var rotation_amount: float = move_toward(0.0, -board.steer_value, turn_rate * delta)
		player.rotate_y(rotation_amount)
	elif player.is_on_floor():
		_straighten_toward_travel(board, delta)
	var nudge_input: float = world_direction.dot(board_forward)
	var jump_pressed: bool = ManagedInput.is_action_just_pressed(InputAction.JUMP)
	RustboardPhysics.apply_with_nudge(player, board, _gravity, TERMINAL_VELOCITY, delta, nudge_input, jump_pressed, player.jump_velocity)
	if not ManagedInput.is_action_pressed(InputAction.DEPLOY_BOARD):
		var horizontal_speed: float = Vector3(player.velocity.x, 0.0, player.velocity.z).length()
		if horizontal_speed > 0.1:
			transitioned.emit(RUNNING)
		else:
			transitioned.emit(IDLE)

## With no steer input, yaws the board toward its direction of travel — sliding
## back down a wall swings the board straight the way a real board would. The
## nearer end leads (forward or backward, whichever the travel direction is
## closer to), so a board sliding tail-first straightens out riding switch
## instead of whipping around 180.
##
## A stall-recovery behavior, so it fades out with speed: gravity swings travel
## toward the fall line constantly, and yawing the board after it at riding
## speed wrenches every line downhill the moment steering eases off.
func _straighten_toward_travel(board: Rustboard, delta: float) -> void:
	var horizontal: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	var speed: float = horizontal.length()
	if speed < board.stop_speed:
		return
	var strength: float = 1.0
	if board.straighten_fade_speed > 0.0:
		strength = 1.0 - clampf(speed / board.straighten_fade_speed, 0.0, 1.0)
	if strength <= 0.0:
		return
	var travel: Vector3 = horizontal / speed
	var forward: Vector3 = -player.transform.basis.z
	if forward.dot(travel) < 0.0:
		travel = -travel
	var angle: float = forward.signed_angle_to(travel, Vector3.UP)
	player.rotate_y(move_toward(0.0, angle, board.straighten_speed * strength * delta))

func exit() -> void:
	player.rustboarding = false
	player.rustboard.stow()
