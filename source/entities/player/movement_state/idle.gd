extends PlayerMovementState

func enter(_previous_state_name: StringName) -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.play_animation(&"Idle", 0.15)
	player.dust_emitter.transition_to(&"Off")

func physics_update(delta: float) -> void:
	_update_vertical_velocity(delta)
	player.move_and_slide()

	if not player.is_on_floor():
		transitioned.emit(FALLING)
	elif wants_jump():
		transitioned.emit(JUMPING)
	elif wants_deploy_board():
		transitioned.emit(RUSTBOARDING)
	elif not is_equal_approx(get_move_axis(), 0.0) or not is_equal_approx(get_strafe_axis(), 0.0):
		transitioned.emit(RUNNING)
