extends GdUnitTestSuite
## Regression: a mode entered from [method PlayerCamera._ready] (lock_mode) used
## to find [member PlayerCameraState.camera] still nil — the base state awaited
## owner.ready before wiring it, but _apply_mode transitions synchronously inside
## _ready, crashing any state whose enter() touches the camera (DownhillChase).

const PLAYER_CAMERA_SCENE: String = "res://systems/camera/player_camera/player_camera.tscn"

func test_lock_mode_enters_downhill_chase_with_camera_wired() -> void:
	var camera: PlayerCamera = (load(PLAYER_CAMERA_SCENE) as PackedScene).instantiate() as PlayerCamera
	camera.lock_mode = true
	camera.mode = PlayerCamera.Mode.DOWNHILL_CHASE
	add_child(camera)
	for frame: int in range(5):
		await await_idle_frame()
	var controller: StateMachine = camera.get_node("%Controller") as StateMachine
	var entered_state_name: String = String(controller.current_state.name)
	# enter() captures the lens FOV on arrival; a nil camera aborted that capture.
	var entered_base_fov: float = controller.current_state.get("_base_fov")
	camera.queue_free()
	await await_idle_frame()
	assert_str(entered_state_name).is_equal("DownhillChase")
	assert_float(entered_base_fov).is_greater(0.0)
