class_name Starship
extends Node3D
## A ship that can land on a [LandingZone]. Its visual comes from its blueprint's model
## scene, so one type covers every hull. Flight is limited to the landing approach for
## now: the ship appears high above its target zone, dives, and brakes in thrust pulses
## until touchdown (see [method land_at]).

const SCENE_PATH := "res://entities/starship/starship.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

@export var blueprint: StarshipBlueprint

## Scene instanced under [member model] at ready. Scene-authored model children are only
## a design-time preview; this replaces them.
@export var model_scene: PackedScene

@export_group("Landing Approach")
## How far above the target zone the ship appears when an approach starts. High enough
## that the pop-in happens beyond anything the camera can frame.
@export var approach_height: float = 300.0
## Top descent speed, hit during the initial dive.
@export var approach_speed_max: float = 90.0
## Proportional brake: descent speed is the remaining distance times this, clamped to
## [member approach_speed_max] and [member touchdown_speed].
@export var approach_gain: float = 1.5
## Distance from the zone where thrust pulsing kicks in.
@export var braking_distance: float = 45.0
## Slowest the ship gets while settling, so the final stretch never stalls out.
@export var touchdown_speed: float = 2.0
## Thrust pulse rate while braking, in pulses per second.
@export var pulse_frequency: float = 1.4
## How deeply each pulse cuts descent speed (0 = no pulsing, 1 = full stalls).
@export_range(0.0, 1.0) var pulse_depth: float = 0.85

@onready var model: Node3D = %Model

var _landing_zone: LandingZone
var _pulse_time: float = 0.0

func _ready() -> void:
	if blueprint != null:
		apply_blueprint(blueprint)
	_refresh_model()
	set_physics_process(_landing_zone != null)

func _physics_process(delta: float) -> void:
	var target: Vector3 = _landing_zone.global_position
	var distance := global_position.distance_to(target)
	global_position = global_position.move_toward(target, _approach_speed(distance, delta) * delta)
	if global_position.is_equal_approx(target):
		_touch_down()

## Starts a landing approach onto [param zone]: the ship appears [member approach_height]
## above it and descends, braking in thrust pulses as it settles. On touchdown the ship
## claims the zone via [method LandingZone.land]. The ship must already be inside the tree.
func land_at(zone: LandingZone) -> void:
	if zone == null:
		return
	_landing_zone = zone
	_pulse_time = 0.0
	global_position = zone.global_position + Vector3.UP * approach_height
	set_physics_process(true)

# Proportional descent speed with pulsed braking: speed tracks the remaining distance, and
# inside the braking envelope a cosine pulse rhythmically cuts it — reads as thrust burns
# steadying the ship out. The pulse never reaches zero, so the approach always converges.
func _approach_speed(distance: float, delta: float) -> float:
	var speed := clampf(distance * approach_gain, touchdown_speed, approach_speed_max)
	if distance < braking_distance:
		_pulse_time += delta
		var pulse := 0.5 - 0.5 * cos(_pulse_time * TAU * pulse_frequency)
		speed *= 1.0 - pulse_depth * pulse
	return speed

func _touch_down() -> void:
	set_physics_process(false)
	global_position = _landing_zone.global_position
	var zone := _landing_zone
	_landing_zone = null
	zone.land(self)

func _refresh_model() -> void:
	if model_scene == null:
		return
	for child in model.get_children():
		child.queue_free()
	model.add_child(model_scene.instantiate())

#region Blueprinting

func apply_blueprint(_blueprint: StarshipBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return
	blueprint = _blueprint
	model_scene = _blueprint.model_scene

static func create(_blueprint: StarshipBlueprint) -> Starship:
	if not _blueprint:
		Log.error("Blueprint required to create Starship")
		return null
	var ship: Starship = SCENE.instantiate()
	ship.apply_blueprint(_blueprint)
	return ship

#endregion
