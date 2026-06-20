extends GdUnitTestSuite
## Tests GameClock tick to hour to day rollover and the derived tick counts.

func _make(tick_interval: float, day_duration: float, day_length: int) -> GameClock:
	var clock := GameClock.new()
	clock.tick_interval = tick_interval
	clock.day_duration = day_duration
	clock.day_length = day_length
	return clock

func test_ticks_per_hour_and_day_derive_from_duration() -> void:
	var clock := _make(1.0, 48.0, 24)  # hour lasts 2 seconds, so 2 ticks per hour
	assert_int(clock.ticks_per_hour).is_equal(2)
	assert_int(clock.ticks_per_day).is_equal(48)
	clock.free()

func test_one_tick_per_hour_when_durations_match() -> void:
	var clock := _make(1.0, 24.0, 24)
	assert_int(clock.ticks_per_hour).is_equal(1)
	clock.tick()
	assert_int(clock.hour).is_equal(1)
	assert_int(clock.day).is_equal(0)
	clock.free()

func test_hour_rolls_over_after_ticks_per_hour() -> void:
	var clock := _make(1.0, 48.0, 24)  # 2 ticks per hour
	clock.tick()
	assert_int(clock.hour).is_equal(0)
	clock.tick()
	assert_int(clock.hour).is_equal(1)
	clock.free()

func test_day_rolls_over_at_day_length() -> void:
	var clock := _make(1.0, 24.0, 24)  # 1 tick per hour, 24 ticks per day
	for _i in 24:
		clock.tick()
	assert_int(clock.day).is_equal(1)
	assert_int(clock.hour).is_equal(0)
	clock.free()

func test_tick_count_increments() -> void:
	var clock := _make(1.0, 24.0, 24)
	clock.tick()
	clock.tick()
	assert_int(clock.count).is_equal(2)
	clock.free()
