@tool
class_name LandingPad
extends Structure
## A dedicated platform offering a [LandingZone] for [Starship]s. The pad is just the
## furniture — ships target the zone, which works anywhere (see [LandingZone]).

const SCENE_PATH := "res://entities/structures/landing_pad/landing_pad.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

@export var blueprint: LandingPadBlueprint

@onready var landing_zone: LandingZone = %LandingZone

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	if blueprint != null:
		apply_blueprint(blueprint)

## Whether a new arrival can be sent to this pad.
func is_available() -> bool:
	return landing_zone.is_available()

## Routes an arriving ship onto the pad's [LandingZone]. Returns false if the pad is taken.
func receive(ship: Starship) -> bool:
	return landing_zone.receive(ship)

#region Blueprinting

func apply_blueprint(_blueprint: LandingPadBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return
	blueprint = _blueprint

static func create(_blueprint: LandingPadBlueprint) -> LandingPad:
	if not _blueprint:
		Log.error("Blueprint required to create LandingPad")
		return null
	var pad: LandingPad = SCENE.instantiate()
	pad.apply_blueprint(_blueprint)
	return pad

#endregion
