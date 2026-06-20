class_name Clock
extends Node
## A tick source: emits [signal ticked] on a fixed interval and counts the ticks. Decoupled from
## whatever responds — many things subscribe to one clock — and drives nothing itself. Responders
## (resource production, autosave, decay, …) connect to [signal ticked].

signal ticked(count: int)

@export var interval: float = 1.0
@export var autostart: bool = true

var count: int = 0
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = maxf(interval, 0.01)
	_timer.autostart = autostart
	_timer.timeout.connect(tick)
	add_child(_timer)

func start() -> void:
	if _timer != null:
		_timer.start()

func stop() -> void:
	if _timer != null:
		_timer.stop()

## Advances one tick — bumps the count and emits. The timer calls this; tests drive it directly.
func tick() -> void:
	count += 1
	ticked.emit(count)
