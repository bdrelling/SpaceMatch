class_name WorkingEffects
extends Node3D
## "This machine is running" feedback: a cartoony squash-and-stretch wobble plus a positional
## rumble on [member target], with a smoke puff stream. Drive [method start] / [method stop] from
## the host's signals (e.g. [signal CraftingStation.work_started] /
## [signal CraftingStation.work_finished]).

const _RECOVER_DURATION: float = 0.1

## The model to wobble; its rest transform is restored on [method stop].
@export var target: Node3D
## Peak scale distortion of a wobble cycle, as a fraction (0.08 = 8%).
@export var wobble_amount: float = 0.08
## Seconds per squash-stretch cycle.
@export var wobble_period: float = 0.2
## Positional rumble radius, in meters.
@export var rumble_amount: float = 0.015

@onready var _smoke: GPUParticles3D = %Smoke

var _base_scale := Vector3.ONE
var _base_position := Vector3.ZERO
var _tween: Tween
var _active := false

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	# A fresh random offset every frame reads as a rumble.
	target.position = _base_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * rumble_amount

## Begins wobbling and smoking. No-op without a target or when already running.
func start() -> void:
	if _active or target == null:
		return
	_active = true
	_base_scale = target.scale
	_base_position = target.position
	if _smoke != null:
		_smoke.emitting = true
	set_process(true)
	_kill_tween()
	_tween = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var squash := _base_scale * Vector3(1.0 + wobble_amount, 1.0 - wobble_amount, 1.0 + wobble_amount)
	var stretch := _base_scale * Vector3(1.0 - wobble_amount, 1.0 + wobble_amount, 1.0 - wobble_amount)
	_tween.tween_property(target, "scale", squash, wobble_period * 0.5)
	_tween.tween_property(target, "scale", stretch, wobble_period * 0.5)

## Eases [member target] back to rest and stops the smoke.
func stop() -> void:
	if not _active:
		return
	_active = false
	if _smoke != null:
		_smoke.emitting = false
	set_process(false)
	_kill_tween()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel()
	_tween.tween_property(target, "scale", _base_scale, _RECOVER_DURATION)
	_tween.tween_property(target, "position", _base_position, _RECOVER_DURATION)

func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
