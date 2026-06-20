extends PlayerCameraState
## Orbit input takes priority; chase resumes only after a brief idle delay.

var _orbit_idle_time: float = 0.0

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	if _handle_orbit_input(delta) or _yaw_panned:
		_orbit_idle_time = 0.0
	else:
		_orbit_idle_time += delta
		if _orbit_idle_time >= camera.chase_resume_delay:
			_handle_chase(delta)
	_yaw_panned = false
