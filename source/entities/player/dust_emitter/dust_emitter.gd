class_name DustEmitter
extends Node3D

const GROUND_SAMPLE_HEIGHT: float = 10.0
const PLAYER_VISUAL_LAYER: int = 2

@onready var _walk: GPUParticles3D = %WalkParticles
@onready var _sprint: GPUParticles3D = %SprintParticles
@onready var _board: GPUParticles3D = %BoardParticles
@onready var _controller: StateMachine = %DustController

var _ground_camera: Camera3D
var _last_color: Color = Color.WHITE

func _ready() -> void:
	_walk.emitting = true
	_sprint.emitting = true
	_board.emitting = true
	_prewarm_gpu_shaders.call_deferred()

func _prewarm_gpu_shaders() -> void:
	_walk.emitting = false
	_sprint.emitting = false
	_board.emitting = false

func setup_ground_sampler() -> void:
	var sub_viewport: SubViewport = SubViewport.new()
	sub_viewport.size = Vector2i(1, 1)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.world_3d = get_viewport().world_3d

	_ground_camera = Camera3D.new()
	_ground_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_ground_camera.size = 0.1
	_ground_camera.near = 0.01
	_ground_camera.far = 100.0
	_ground_camera.cull_mask = 0xFFFFF & ~PLAYER_VISUAL_LAYER

	sub_viewport.add_child(_ground_camera)
	add_child(sub_viewport)

func _physics_process(_delta: float) -> void:
	_update_ground_color()

func transition_to(state_name: StringName) -> void:
	_controller.on_child_transitioned(state_name)

func set_all_emitting(value: bool) -> void:
	_walk.emitting = value
	_sprint.emitting = value
	_board.emitting = value

func set_active_emitter(emitter_name: StringName) -> void:
	_walk.emitting = (emitter_name == &"Walk")
	_sprint.emitting = (emitter_name == &"Sprint")
	_board.emitting = (emitter_name == &"Board")

func _update_ground_color() -> void:
	if _ground_camera == null:
		return
	if not _walk.emitting and not _sprint.emitting and not _board.emitting:
		return
	_ground_camera.global_position = global_position + Vector3(0.0, GROUND_SAMPLE_HEIGHT, 0.0)
	_ground_camera.global_rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	var sub_viewport: SubViewport = _ground_camera.get_parent() as SubViewport
	var image: Image = sub_viewport.get_texture().get_image()
	if image == null:
		return
	var pixel: Color = image.get_pixel(0, 0)
	if pixel.is_equal_approx(_last_color):
		return
	_last_color = pixel
	for emitter: GPUParticles3D in [_walk, _sprint, _board]:
		var shader_material: ShaderMaterial = emitter.process_material as ShaderMaterial
		if shader_material != null:
			shader_material.set_shader_parameter(&"ground_color", pixel)
