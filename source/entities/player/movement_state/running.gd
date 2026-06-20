extends PlayerMovementState

var _sprinting: bool = false

func enter(_previous_state_name: StringName) -> void:
	_sprinting = false
	player.play_animation(&"Walk", 0.65)
	player.dust_emitter.transition_to(&"Walk")

func physics_update(delta: float) -> void:
	_update_velocities(delta)

	player.move_and_slide()

	if not player.is_on_floor():
		transitioned.emit(FALLING)
	elif wants_jump():
		transitioned.emit(JUMPING)
	elif wants_deploy_board():
		transitioned.emit(RUSTBOARDING)
	elif is_equal_approx(get_move_axis(), 0.0) and is_equal_approx(get_strafe_axis(), 0.0):
		transitioned.emit(IDLE)
	else:
		_update_locomotion()

func _update_locomotion() -> void:
	var sprinting: bool = player.is_sprinting()
	if sprinting == _sprinting:
		return
	_sprinting = sprinting
	if sprinting:
		player.play_animation(&"Run", 0.35)
		player.dust_emitter.transition_to(&"Sprint")
	else:
		player.play_animation(&"Walk", 0.35)
		player.dust_emitter.transition_to(&"Walk")
