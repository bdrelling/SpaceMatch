class_name AtmosphereCycleDriver
extends Node
## Advances an [Atmosphere]'s [AtmosphereCycle] sun dial in periodic eased glides:
## every [member step_interval_seconds] the dial moves by however much dial time the
## interval covers, easing in and out so the shift never snaps, then holds still —
## the environment only rebuilds while a glide is running.

## The atmosphere whose cycle this drives. Inspector-wired.
@export var atmosphere: Atmosphere
## Real minutes for the dial to cover a full 360° day.
@export_range(1.0, 240.0, 0.5) var day_length_minutes: float = 20.0
## Seconds between glides.
@export_range(1.0, 60.0, 0.5) var step_interval_seconds: float = 5.0
## Fraction of each interval spent gliding; the rest holds still.
@export_range(0.1, 1.0, 0.05) var glide_fraction: float = 0.5

var _tween: Tween

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = step_interval_seconds
	timer.autostart = true
	timer.timeout.connect(_advance)
	add_child(timer, false, Node.INTERNAL_MODE_BACK)

func _advance() -> void:
	if atmosphere == null or atmosphere.cycle == null:
		return
	var step := 360.0 / (day_length_minutes * 60.0) * step_interval_seconds
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(
		atmosphere.cycle, "sun_angle_degrees",
		atmosphere.cycle.sun_angle_degrees + step, step_interval_seconds * glide_fraction
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
