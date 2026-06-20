class_name PlayerMovementState
extends State

const TERMINAL_VELOCITY: float = -54.0

const RUSTBOARDING = &"Rustboarding"
const FALLING = &"Falling"
const FLYING = &"Flying"
const IDLE = &"Idle"
const JUMPING = &"Jumping"
const RUNNING = &"Running"

var player: Player

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	await owner.ready
	player = owner as Player
	assert(player != null)

#region Input Helpers

func get_move_axis() -> float:
	return ManagedInput.get_axis(InputAction.MOVE_BACKWARD, InputAction.MOVE_FORWARD)

func get_strafe_axis() -> float:
	return ManagedInput.get_axis(InputAction.STRAFE_LEFT, InputAction.STRAFE_RIGHT)

func get_move_direction() -> Vector3:
	var direction := Vector3.ZERO
	if ManagedInput.is_action_pressed(InputAction.STRAFE_RIGHT):
		direction.x += 1
	if ManagedInput.is_action_pressed(InputAction.STRAFE_LEFT):
		direction.x -= 1
	if ManagedInput.is_action_pressed(InputAction.MOVE_BACKWARD):
		direction.z += 1
	if ManagedInput.is_action_pressed(InputAction.MOVE_FORWARD):
		direction.z -= 1
	if direction != Vector3.ZERO:
		direction = direction.normalized()
	return direction

func wants_jump() -> bool:
	return ManagedInput.is_action_just_pressed(InputAction.JUMP)

func wants_deploy_board() -> bool:
	return ManagedInput.is_action_just_pressed(InputAction.DEPLOY_BOARD)

#endregion

#region Utilities

func _update_velocities(delta: float) -> void:
	_update_forward_velocity(delta)
	_update_vertical_velocity(delta)

func _update_forward_velocity(delta: float) -> void:
	var move_axis: float = get_move_axis()
	var strafe_axis: float = get_strafe_axis()
	var raw_input: Vector3 = Vector3(strafe_axis, 0.0, -move_axis)
	if raw_input.length_squared() > 1.0:
		raw_input = raw_input.normalized()
	var camera_basis: Basis = player.get_camera_yaw_basis()
	var world_direction: Vector3 = camera_basis * raw_input
	var move_speed: float = player.move_speed
	if player.is_sprinting():
		move_speed *= player.sprint_multiplier
	player.velocity.x = world_direction.x * move_speed
	player.velocity.z = world_direction.z * move_speed
	if player.movement_scheme == Player.MovementScheme.STRAFE:
		# Body always faces camera-forward; input strafes/back-pedals without turning.
		player.pivot_toward(camera_basis * Vector3.FORWARD, delta)
	elif world_direction.length_squared() > 0.001:
		# Body turns to face wherever it is moving.
		player.pivot_toward(world_direction, delta)

func _update_vertical_velocity(delta: float) -> void:
	player.velocity.y -= _gravity * delta
	player.velocity.y = maxf(player.velocity.y, TERMINAL_VELOCITY)

#endregion
