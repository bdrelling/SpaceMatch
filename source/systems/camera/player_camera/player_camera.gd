@tool
class_name PlayerCamera
extends Node3D
## Drop-in drift-follow camera backed by PhantomCamera3D.
##
## Instance the [code]player_camera.tscn[/code] scene in any level and wire
## [member follow_target] to the node the camera should follow (any [Node3D])
## directly in the scene.  On [method _ready] it configures the pre-built
## PhantomCamera3D rig. The camera knows nothing about who follows it: consumers
## read its orientation via [method get_yaw_basis] and react to [signal mode_changed].
##
## Leave [member follow_target] unset (null) for a fixed scene camera; the
## follow logic no-ops gracefully in that case.
##
## Behaviour is driven by a [StateMachine] of [PlayerCameraState] children. The
## [member mode] enum stays the public selector (settings, editor) and maps onto
## the concrete state to run:
##   LOCKED_YAW — fixed yaw, no player rotation input.
##   ORBIT — rotate_left / rotate_right orbit the camera around the target.
##   CHASE — steerable follow-cam: orbit input turns the view (pairs with the STRAFE movement scheme).
##   ORBIT_AND_CHASE — orbit input takes priority; chase fills in when no orbit was applied.
##   DOWNHILL_CHASE — racing follow-cam: trails the target's heading on its own,
##   widens the FOV with speed, and looks ahead along the travel direction.

enum Mode {
	LOCKED_YAW,
	ORBIT,
	CHASE,
	ORBIT_AND_CHASE,
	DOWNHILL_CHASE,
}

## Emitted whenever [member mode] changes, so a consumer (e.g. the player picking
## its movement scheme) can react without the camera knowing anything about it.
signal mode_changed(new_mode: Mode)

const ORBIT_SPEED: float = 90.0
const TILT_SPEED: float = 40.0
const MOUSE_SENSITIVITY: float = 0.2
const SCROLL_TILT_STEP: float = 5.0
const SCROLL_FRICTION: float = 6.0
const TRACKPAD_SENSITIVITY: float = 8.0
const PAN_SMOOTHING: float = 15.0
const PITCH_MIN: float = -60.0
const PITCH_MAX: float = -10.0
const SPRING_LENGTH_AT_PITCH_MIN: float = 14.0
const SPRING_LENGTH_AT_PITCH_MAX: float = 7.0

@export var mode: Mode = Mode.ORBIT_AND_CHASE:
	set(value):
		mode = value
		_apply_mode()
		mode_changed.emit(value)
## Highlight focus mode for this camera, written through to its [SilhouetteOutline] child (which
## also exports it for standalone use) whenever this value changes — in the editor or at runtime.
## When true only the single sticky focus is highlighted; when false every in-range interactable
## highlights. Configure it here to drive the camera as a reusable unit. See [InteractionFocus].
@export var exclusive_highlight: bool = true:
	set(value):
		exclusive_highlight = value
		_apply_exclusive_highlight()
@export var follow_target: Node3D
@export var follow_offset: Vector3 = Vector3(0.0, 5.0, 0.0)
@export var follow_damping_value: Vector3 = Vector3(0.15, 0.15, 0.15)
@export var look_at_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var initial_pitch: float = -20.0
@export var initial_yaw: float = 0.0
@export var orbit_speed_degrees: float = ORBIT_SPEED
@export var tilt_speed_degrees: float = TILT_SPEED
@export var mouse_sensitivity: float = MOUSE_SENSITIVITY
@export var scroll_tilt_step: float = SCROLL_TILT_STEP
@export var scroll_friction: float = SCROLL_FRICTION
## Multiplier on [member mouse_sensitivity] for trackpad two-finger pan gestures,
## whose raw deltas are far smaller than mouse-motion pixels. Scales both axes of
## the gesture (yaw + tilt) so the two-finger drag feels symmetric.
@export var trackpad_sensitivity: float = TRACKPAD_SENSITIVITY
## Exponential drain rate (per second) for queued pan input — pan and pan-gesture
## deltas spend over a short window instead of landing on a single physics tick.
## Higher is snappier; lower glides longer behind the gesture.
@export var pan_smoothing: float = PAN_SMOOTHING
@export var chase_smoothing: float = 2.0
@export var chase_resume_delay: float = 0.4
## When true the scene-authored [member mode] is final: the camera-mode setting
## neither overrides it at ready nor on settings changes. For levels whose
## gameplay is built around one mode (e.g. DOWNHILL_CHASE racing demos).
@export var lock_mode: bool = false

@export_group("Downhill Chase")
## FOV at [member downhill_fov_full_speed]; eases back to the scene's base FOV at rest.
@export var downhill_fov_max_degrees: float = 75.0
## Speed (m/s) at which the FOV reaches [member downhill_fov_max_degrees].
@export var downhill_fov_full_speed: float = 30.0
## How far (meters) the follow point slides ahead along the travel direction at full speed.
@export var downhill_lookahead: float = 3.0

@export_group("Look Direction")
## Direction signs for look input — flip a component to -1 to invert that axis.
## All direction lives here as single values (no hidden negation buried in the
## camera math), so each axis is one flip away from inverting. X drives yaw
## (horizontal), Y drives pitch (vertical). Wire these to player-facing invert
## toggles later, the way [member Settings.game.invert_y_axis] already drives tilt.
##
## Mouse and trackpad differ on X because the macOS trackpad pan gesture reports
## horizontal delta opposite to mouse motion.
@export var mouse_pan_sign: Vector2 = Vector2(-1.0, -1.0)
@export var trackpad_pan_sign: Vector2 = Vector2(1.0, 1.0)
## Sign for gamepad/keyboard orbit (rotate_left / rotate_right). Flip to invert.
@export var orbit_sign: float = -1.0

@export_group("Input Actions")
## Action names this camera polls. Defaulted to the project's bindings; the game can remap
## them in the inspector, so the camera carries no dependency on a global action registry.
@export var pan_action: StringName = &"camera_pan"
@export var tilt_up_action: StringName = &"tilt_up"
@export var tilt_down_action: StringName = &"tilt_down"
@export var rotate_left_action: StringName = &"rotate_left"
@export var rotate_right_action: StringName = &"rotate_right"

@onready var phantom_camera: PhantomCamera3D = %PhantomCamera3D
@onready var _camera: Camera3D = %Camera3D
@onready var _controller: StateMachine = %Controller

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	(%PhantomCamera3D as Node3D).rotation_degrees.x = initial_pitch

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_apply_exclusive_highlight()
	_configure_phantom_camera()
	if lock_mode:
		_apply_mode()
	else:
		mode = Settings.game.camera_mode
	Settings.game.changed.connect(_on_settings_changed)
	await get_tree().process_frame
	await get_tree().process_frame
	_camera.current = true

## Writes [member exclusive_highlight] through to this camera's [SilhouetteOutline] child, so the
## camera's value drives the outline node (in editor via the setter, at runtime also via _ready).
func _apply_exclusive_highlight() -> void:
	var outline: SilhouetteOutline = _silhouette_outline()
	if outline != null:
		outline.exclusive_highlight = exclusive_highlight

func _silhouette_outline() -> SilhouetteOutline:
	var found: Array[Node] = find_children("*", "SilhouetteOutline", true, false)
	return found[0] as SilhouetteOutline if not found.is_empty() else null

func _on_settings_changed() -> void:
	if lock_mode:
		return
	mode = Settings.game.camera_mode

## Spring length is a pure function of pitch: the camera pulls back as it tilts
## toward [constant PITCH_MIN] and tucks in toward [constant PITCH_MAX]. Both the
## tilt input and initial setup derive the spring from here so they never disagree
## (a mismatch would snap the camera on the first tilt event).
static func spring_length_for_pitch(pitch_degrees: float) -> float:
	var pitch_ratio: float = (clampf(pitch_degrees, PITCH_MIN, PITCH_MAX) - PITCH_MAX) / (PITCH_MIN - PITCH_MAX)
	return lerpf(SPRING_LENGTH_AT_PITCH_MAX, SPRING_LENGTH_AT_PITCH_MIN, pitch_ratio)

## Camera yaw in radians — the heading the player faces when moving camera-relative.
func get_facing_yaw() -> float:
	if not is_instance_valid(phantom_camera):
		return 0.0
	return phantom_camera.get_third_person_rotation().y

func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, get_facing_yaw())

## The rendered Camera3D this rig drives — for states that animate lens
## properties (FOV) that the phantom camera doesn't manage.
func get_camera_3d() -> Camera3D:
	return _camera

func snap() -> void:
	if is_instance_valid(phantom_camera) and is_instance_valid(follow_target):
		phantom_camera.set_third_person_rotation_degrees(Vector3(initial_pitch, initial_yaw, 0.0))

func _configure_phantom_camera() -> void:
	phantom_camera.follow_damping_value = follow_damping_value
	phantom_camera.follow_offset = follow_offset
	phantom_camera.spring_length = spring_length_for_pitch(initial_pitch)
	if is_instance_valid(follow_target):
		phantom_camera.follow_target = follow_target

func _apply_mode() -> void:
	if Engine.is_editor_hint():
		return
	# Guard on the controller (an @onready child) rather than is_node_ready(): this
	# lets the mode set in _ready apply itself, so the camera is self-sufficient
	# and needs no external trigger.
	if not is_instance_valid(_controller):
		return
	_controller.on_child_transitioned(_state_name_for_mode(mode))

func _state_name_for_mode(value: Mode) -> StringName:
	match value:
		Mode.ORBIT:
			return PlayerCameraState.ORBIT
		Mode.CHASE:
			return PlayerCameraState.CHASE
		Mode.ORBIT_AND_CHASE:
			return PlayerCameraState.ORBIT_AND_CHASE
		Mode.DOWNHILL_CHASE:
			return PlayerCameraState.DOWNHILL_CHASE
		_:
			return PlayerCameraState.LOCKED_YAW
