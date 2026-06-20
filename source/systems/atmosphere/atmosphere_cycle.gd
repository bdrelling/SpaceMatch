@tool
class_name AtmosphereCycle
extends Resource
## Blends two [AtmosphereConfig] blueprints — a day look and a night look — over a single
## sun dial. [member sun_angle_degrees] is an exact position, meant to be set by whatever
## owns game time: 0 = full day, 90 = sunset begins, 180 = full night, 270 = sunrise
## begins, with the blend easing across each transition quarter (135 is exactly
## mid-sunset). Floats, colors, and vectors interpolate; anything unblendable (modes,
## toggles) snaps to whichever side dominates.
##
## The endpoint configs stay pure blueprints — the cycle never writes to them; it bakes a
## throwaway blended config on every read.

@export var day: AtmosphereConfig:
	set(value):
		_swap_endpoint(day, value)
		day = value
		emit_changed()
@export var night: AtmosphereConfig:
	set(value):
		_swap_endpoint(night, value)
		night = value
		emit_changed()
## 0 = full day, 90 = sunset begins, 180 = full night, 270 = sunrise begins. Wraps, so a
## tween can run past 360 for a continuous cycle; setting it from code re-applies any
## listening [Atmosphere].
@export_range(0.0, 360.0, 0.1) var sun_angle_degrees: float = 0.0:
	set(value):
		sun_angle_degrees = wrapf(value, 0.0, 360.0)
		emit_changed()
## Compass bearing of the derived key light's arc.
@export var sun_azimuth_degrees: float = 150.0
## How high the sun climbs at the top of the day.
@export_range(5.0, 90.0, 0.5) var noon_elevation_degrees: float = 55.0

func is_complete() -> bool:
	return day != null and night != null

## 1 across the day quarter-circle, 0 across the night one, easing through the sunset
## (90–180) and sunrise (270–360) quarters in between. A pure function of the dial, so a
## given degree always lands the same blend.
func day_weight() -> float:
	var angle := wrapf(sun_angle_degrees, 0.0, 360.0)
	if angle < 90.0:
		return 1.0
	if angle < 180.0:
		return smoothstep(0.0, 1.0, (180.0 - angle) / 90.0)
	if angle < 270.0:
		return 0.0
	return smoothstep(0.0, 1.0, (angle - 270.0) / 90.0)

## Bakes a one-off config at the current dial position; the endpoints are never touched.
func blended() -> AtmosphereConfig:
	var weight := day_weight()
	var result := AtmosphereConfig.new()
	for property in result.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE):
			continue
		var key: StringName = property.name
		var from: Variant = night.get(key)
		var to: Variant = day.get(key)
		match typeof(from):
			TYPE_FLOAT, TYPE_COLOR, TYPE_VECTOR3:
				result.set(key, lerp(from, to, weight))
			_:
				result.set(key, to if weight >= 0.5 else from)
	return result

## Key-light rotation for the current dial position: the day sun rides a fixed-azimuth
## arc — highest at dial 0, on the horizon where the transitions start — and eases toward
## the night blueprint's authored moon angle as night takes over.
func sun_rotation_degrees() -> Vector3:
	var sun_height := maxf(cos(deg_to_rad(sun_angle_degrees)), 0.0)
	var arc := Vector3(-sun_height * noon_elevation_degrees, sun_azimuth_degrees, 0.0)
	return night.sun_rotation_degrees.lerp(arc, day_weight())

# Re-emits endpoint edits as our own change so a listening Atmosphere re-applies live.
func _swap_endpoint(old_value: AtmosphereConfig, new_value: AtmosphereConfig) -> void:
	if old_value and old_value.changed.is_connected(emit_changed):
		old_value.changed.disconnect(emit_changed)
	if new_value:
		new_value.changed.connect(emit_changed)
