extends PlayerCameraState
## Steerable follow-cam: orbit input turns the view. Paired with the STRAFE
## movement scheme, the body faces camera-forward, so the camera sits behind the
## player and orbiting turns the player.

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	_handle_orbit_input(delta)
