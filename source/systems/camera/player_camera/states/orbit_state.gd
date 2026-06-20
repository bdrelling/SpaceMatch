extends PlayerCameraState
## rotate_left / rotate_right orbit the camera around the target.

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	_handle_orbit_input(delta)
