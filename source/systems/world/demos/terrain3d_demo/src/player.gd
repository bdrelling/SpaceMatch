extends CharacterBody3D

@export var MOVE_SPEED: float = 50.0
@export var JUMP_SPEED: float = 2.0
@export var first_person: bool = false :
	set(p_value):
		first_person = p_value
		if first_person:
			var tween: Tween = create_tween()
			tween.tween_property(_arm, "spring_length", 0.0, .33)
			tween.tween_callback(_body.set_visible.bind(false))
		else:
			_body.visible = true
			create_tween().tween_property(_arm, "spring_length", 6.0, .33)

@export var gravity_enabled: bool = true :
	set(p_value):
		gravity_enabled = p_value
		if not gravity_enabled:
			velocity.y = 0

@export var collision_enabled: bool = true :
	set(p_value):
		collision_enabled = p_value
		_collision_body.disabled = not collision_enabled
		_collision_ray.disabled = not collision_enabled

@onready var _arm: SpringArm3D = $CameraManager/Arm as SpringArm3D
@onready var _body: MeshInstance3D = $Body as MeshInstance3D
@onready var _collision_body: CollisionShape3D = $CollisionShapeBody as CollisionShape3D
@onready var _collision_ray: CollisionShape3D = $CollisionShapeRay as CollisionShape3D


func _physics_process(p_delta: float) -> void:
	var direction: Vector3 = get_camera_relative_input()
	var h_veloc: Vector2 = Vector2(direction.x, direction.z).normalized() * MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		h_veloc *= 2
	velocity.x = h_veloc.x
	velocity.z = h_veloc.y
	if gravity_enabled:
		velocity.y -= 40 * p_delta
	move_and_slide()


func get_camera_relative_input() -> Vector3:
	var cam: Camera3D = %Camera3D as Camera3D
	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_A):
		input_dir -= cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_W):
		input_dir -= cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		velocity.y += JUMP_SPEED + MOVE_SPEED * .016
	if Input.is_key_pressed(KEY_Q):
		velocity.y -= JUMP_SPEED + MOVE_SPEED * .016
	if Input.is_key_pressed(KEY_KP_ADD) or Input.is_key_pressed(KEY_EQUAL):
		MOVE_SPEED = clamp(MOVE_SPEED + .5, 5, 9999)
	if Input.is_key_pressed(KEY_KP_SUBTRACT) or Input.is_key_pressed(KEY_MINUS):
		MOVE_SPEED = clamp(MOVE_SPEED - .5, 5, 9999)
	return input_dir


func _input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = p_event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				MOVE_SPEED = clamp(MOVE_SPEED + 5, 5, 9999)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				MOVE_SPEED = clamp(MOVE_SPEED - 5, 5, 9999)

	elif p_event is InputEventKey:
		var key_event: InputEventKey = p_event as InputEventKey
		if key_event.pressed:
			if key_event.keycode == KEY_V:
				first_person = not first_person
			elif key_event.keycode == KEY_G:
				gravity_enabled = not gravity_enabled
			elif key_event.keycode == KEY_C:
				collision_enabled = not collision_enabled
		elif key_event.keycode in [KEY_Q, KEY_E, KEY_SPACE]:
			velocity.y = 0
