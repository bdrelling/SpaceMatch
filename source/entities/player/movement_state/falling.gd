extends PlayerMovementState

func enter(_previous_state_name: StringName) -> void:
	player.play_animation(&"Idle", 0.2)
	player.dust_emitter.transition_to(&"Off")

func physics_update(delta: float) -> void:
	_update_velocities(delta)

	player.move_and_slide()

	if wants_deploy_board():
		transitioned.emit(RUSTBOARDING)
	elif player.is_on_floor():
		if is_equal_approx(player.velocity.x, 0.0) and is_equal_approx(player.velocity.z, 0.0):
			transitioned.emit(IDLE)
		else:
			transitioned.emit(RUNNING)
