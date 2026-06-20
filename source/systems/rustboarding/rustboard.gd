class_name Rustboard
extends Node3D

const SCENE_PATH := "res://systems/rustboarding/rustboard.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

#region Tuning bounds
## Min/max/step/default for each tunable — the single source of truth shared by the
## RustboardBlueprint @export defaults, this node's runtime fields, and the debug
## menu's drag controls. Mirrors the Player stat-bounds pattern.

const MAX_SPEED_MIN: float = 5.0
const MAX_SPEED_MAX: float = 100.0
const MAX_SPEED_STEP: float = 0.5
const MAX_SPEED_DEFAULT: float = 34.0

const NUDGE_ACCELERATION_MIN: float = 0.0
const NUDGE_ACCELERATION_MAX: float = 20.0
const NUDGE_ACCELERATION_STEP: float = 0.1
const NUDGE_ACCELERATION_DEFAULT: float = 2.5

const SLOPE_ACCELERATION_SCALE_MIN: float = 0.0
const SLOPE_ACCELERATION_SCALE_MAX: float = 6.0
const SLOPE_ACCELERATION_SCALE_STEP: float = 0.05
const SLOPE_ACCELERATION_SCALE_DEFAULT: float = 1.6

const KINETIC_FRICTION_MIN: float = 0.0
const KINETIC_FRICTION_MAX: float = 2.0
const KINETIC_FRICTION_STEP: float = 0.01
const KINETIC_FRICTION_DEFAULT: float = 0.1

const STATIC_FRICTION_MIN: float = 0.0
const STATIC_FRICTION_MAX: float = 2.0
const STATIC_FRICTION_STEP: float = 0.01
const STATIC_FRICTION_DEFAULT: float = 0.2

const LATERAL_FRICTION_MIN: float = 0.0
const LATERAL_FRICTION_MAX: float = 30.0
const LATERAL_FRICTION_STEP: float = 0.1
const LATERAL_FRICTION_DEFAULT: float = 6.0

const STOP_SPEED_MIN: float = 0.0
const STOP_SPEED_MAX: float = 5.0
const STOP_SPEED_STEP: float = 0.05
const STOP_SPEED_DEFAULT: float = 0.5

const ROTATION_SPEED_MIN: float = 0.0
const ROTATION_SPEED_MAX: float = 10.0
const ROTATION_SPEED_STEP: float = 0.05
const ROTATION_SPEED_DEFAULT: float = 1.5

const DEPLOY_TILT_DEGREES_MIN: float = -30.0
const DEPLOY_TILT_DEGREES_MAX: float = 30.0
const DEPLOY_TILT_DEGREES_STEP: float = 0.5
const DEPLOY_TILT_DEGREES_DEFAULT: float = 4.0

const ALIGNMENT_SPEED_MIN: float = 0.0
const ALIGNMENT_SPEED_MAX: float = 30.0
const ALIGNMENT_SPEED_STEP: float = 0.1
const ALIGNMENT_SPEED_DEFAULT: float = 10.0

const STRAIGHTEN_SPEED_MIN: float = 0.0
const STRAIGHTEN_SPEED_MAX: float = 10.0
const STRAIGHTEN_SPEED_STEP: float = 0.05
const STRAIGHTEN_SPEED_DEFAULT: float = 1.5

const AIR_RIGHTING_SPEED_MIN: float = 0.0
const AIR_RIGHTING_SPEED_MAX: float = 30.0
const AIR_RIGHTING_SPEED_STEP: float = 0.1
const AIR_RIGHTING_SPEED_DEFAULT: float = 2.0

const STRAIGHTEN_FADE_SPEED_MIN: float = 0.0
const STRAIGHTEN_FADE_SPEED_MAX: float = 30.0
const STRAIGHTEN_FADE_SPEED_STEP: float = 0.1
const STRAIGHTEN_FADE_SPEED_DEFAULT: float = 6.0

const CARVE_GRIP_MIN: float = 0.0
const CARVE_GRIP_MAX: float = 12.0
const CARVE_GRIP_STEP: float = 0.05
const CARVE_GRIP_DEFAULT: float = 0.0

const SPEED_TURN_FALLOFF_MIN: float = 0.0
const SPEED_TURN_FALLOFF_MAX: float = 0.2
const SPEED_TURN_FALLOFF_STEP: float = 0.001
const SPEED_TURN_FALLOFF_DEFAULT: float = 0.0

const STEER_RAMP_MIN: float = 0.0
const STEER_RAMP_MAX: float = 20.0
const STEER_RAMP_STEP: float = 0.1
const STEER_RAMP_DEFAULT: float = 0.0

const LEAN_DEGREES_MIN: float = 0.0
const LEAN_DEGREES_MAX: float = 45.0
const LEAN_DEGREES_STEP: float = 0.5
const LEAN_DEGREES_DEFAULT: float = 0.0

const NORMAL_SMOOTHING_MIN: float = 0.0
const NORMAL_SMOOTHING_MAX: float = 30.0
const NORMAL_SMOOTHING_STEP: float = 0.1
const NORMAL_SMOOTHING_DEFAULT: float = 0.0
#endregion

@export var blueprint: RustboardBlueprint

## Floor normal under the board last physics frame; ZERO while airborne.
## Maintained by [RustboardPhysics] to sense convex corners (lip launches).
var last_floor_normal: Vector3 = Vector3.ZERO

## Current steer value in [-1, 1], after [member steer_ramp] smoothing. Written
## by the rustboarding movement state, read for the carve lean visuals.
var steer_value: float = 0.0

## Floor normal smoothed at [member normal_smoothing] per second; ZERO while
## airborne. Drives slope acceleration so faceted terrain pulls evenly instead
## of ticking seam to seam. Maintained by [RustboardPhysics].
var smoothed_floor_normal: Vector3 = Vector3.ZERO

@onready var mesh: MeshInstance3D = %Mesh
@onready var _controller: StateMachine = %Controller

#region Tuning

@export_group("Speed")
@export var max_speed: float = MAX_SPEED_DEFAULT
@export var nudge_acceleration: float = NUDGE_ACCELERATION_DEFAULT
@export var slope_acceleration_scale: float = SLOPE_ACCELERATION_SCALE_DEFAULT

@export_group("Friction")
@export var kinetic_friction: float = KINETIC_FRICTION_DEFAULT
@export var static_friction: float = STATIC_FRICTION_DEFAULT
@export var lateral_friction: float = LATERAL_FRICTION_DEFAULT
@export var stop_speed: float = STOP_SPEED_DEFAULT

@export_group("Handling")
@export var rotation_speed: float = ROTATION_SPEED_DEFAULT
@export var deploy_tilt_degrees: float = DEPLOY_TILT_DEGREES_DEFAULT
@export var alignment_speed: float = ALIGNMENT_SPEED_DEFAULT
@export var straighten_speed: float = STRAIGHTEN_SPEED_DEFAULT
@export var air_righting_speed: float = AIR_RIGHTING_SPEED_DEFAULT
@export var straighten_fade_speed: float = STRAIGHTEN_FADE_SPEED_DEFAULT

@export_group("Carve")
@export var carve_grip: float = CARVE_GRIP_DEFAULT
@export var speed_turn_falloff: float = SPEED_TURN_FALLOFF_DEFAULT
@export var steer_ramp: float = STEER_RAMP_DEFAULT
@export var lean_degrees: float = LEAN_DEGREES_DEFAULT
@export var normal_smoothing: float = NORMAL_SMOOTHING_DEFAULT

#endregion

func _ready() -> void:
	apply_blueprint(blueprint)

func deploy() -> void:
	_controller.on_child_transitioned(RustboardState.DEPLOYED)

func stow() -> void:
	_controller.on_child_transitioned(RustboardState.STOWED)

#region Blueprinting

# Copies the tunable fields off the blueprint without swapping the blueprint ref.
# Cheap enough to call live every frame while a value is being dragged.
func apply_stats(_blueprint: RustboardBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply stats; blueprint not found")
		return
	max_speed = _blueprint.max_speed
	nudge_acceleration = _blueprint.nudge_acceleration
	slope_acceleration_scale = _blueprint.slope_acceleration_scale
	kinetic_friction = _blueprint.kinetic_friction
	static_friction = _blueprint.static_friction
	lateral_friction = _blueprint.lateral_friction
	stop_speed = _blueprint.stop_speed
	rotation_speed = _blueprint.rotation_speed
	deploy_tilt_degrees = _blueprint.deploy_tilt_degrees
	alignment_speed = _blueprint.alignment_speed
	straighten_speed = _blueprint.straighten_speed
	air_righting_speed = _blueprint.air_righting_speed
	straighten_fade_speed = _blueprint.straighten_fade_speed
	carve_grip = _blueprint.carve_grip
	speed_turn_falloff = _blueprint.speed_turn_falloff
	steer_ramp = _blueprint.steer_ramp
	lean_degrees = _blueprint.lean_degrees
	normal_smoothing = _blueprint.normal_smoothing

func apply_blueprint(_blueprint: RustboardBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return
	blueprint = _blueprint
	apply_stats(_blueprint)

static func create(_blueprint: RustboardBlueprint) -> Rustboard:
	if not _blueprint:
		Log.error("Blueprint required to create Rustboard")
		return null
	var rustboard: Rustboard = SCENE.instantiate()
	rustboard.apply_blueprint(_blueprint)
	return rustboard

#endregion
