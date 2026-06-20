class_name DeployedRustboardState
extends RustboardState

func enter(_previous_state_name: StringName) -> void:
	rustboard.mesh.rotation_degrees = Vector3(rustboard.deploy_tilt_degrees, 0.0, 0.0)
	rustboard.visible = true
	rustboard.reset_physics_interpolation()
