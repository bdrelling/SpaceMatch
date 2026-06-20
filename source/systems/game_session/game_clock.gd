class_name GameClock
extends Node
## The game's master clock: fires [signal ticked] every [member tick_interval] real seconds and
## advances the in-game calendar held in [member state]. Hour and day rollover derive from the day's
## real length, so [member ticks_per_hour] and [member ticks_per_day] share one rule. [method bind]
## points it at a saved [GameClockState] so day and hour persist.

signal ticked(count: int)
signal hour_passed(day: int, hour: int)
signal day_passed(day: int)

@export var tick_interval: float = 0.5  # real seconds between ticks
@export var day_duration: float = 600.0  # real seconds for a full day
@export var day_length: int = 24  # hours per day
@export var autostart: bool = true

## Persisted position (day, hour, tick count). Replaced by [method bind] to share a save's data.
var state: GameClockState = GameClockState.new()

var day: int:
	get: return state.day

var hour: int:
	get: return state.hour

var count: int:
	get: return state.count

## Ticks that make one in-game hour, derived from the day's real length.
var ticks_per_hour: int:
	get:
		var hour_duration := day_duration / float(maxi(day_length, 1))
		return maxi(1, roundi(hour_duration / maxf(tick_interval, 0.01)))

## Ticks that make a full day.
var ticks_per_day: int:
	get: return ticks_per_hour * day_length

var _timer: Timer
var _ticks_this_hour: int = 0

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = maxf(tick_interval, 0.01)
	_timer.autostart = autostart
	_timer.timeout.connect(tick)
	add_child(_timer)

## Points the clock at [param clock_state] so day and hour read and write a saved game's data.
func bind(clock_state: GameClockState) -> void:
	if clock_state != null:
		state = clock_state
	_ticks_this_hour = 0

func start() -> void:
	if _timer != null:
		_timer.start()

func stop() -> void:
	if _timer != null:
		_timer.stop()

## Advances one tick — bumps the count, emits, and rolls the hour once enough ticks accrue. The
## timer calls this; tests drive it directly.
func tick() -> void:
	state.count += 1
	ticked.emit(state.count)
	_ticks_this_hour += 1
	if _ticks_this_hour >= ticks_per_hour:
		_ticks_this_hour = 0
		_advance_hour()

func _advance_hour() -> void:
	state.hour += 1
	if state.hour >= day_length:
		state.hour = 0
		state.day += 1
		day_passed.emit(state.day)
	hour_passed.emit(state.day, state.hour)
