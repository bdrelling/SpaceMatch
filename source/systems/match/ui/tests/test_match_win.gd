extends MatchTestCase
## Win conditions: health-out, warp jump, and warp capacity.


# The encounter is over once a combatant is out of health, and names the loser.
func test_encounter_over_when_a_combatant_falls() -> void:
	var enc := _encounter()
	assert_bool(enc.is_over()).is_false()
	enc.deal_damage(enc.opponent, enc.opponent_max_health)
	assert_bool(enc.is_over()).is_true()
	assert_object(enc.defeated()).is_same(enc.opponent)


# Filling warp lets the player Jump — expending the meter and winning the encounter outright.
func test_player_jump_at_full_warp_wins() -> void:
	var enc := _encounter()
	enc.warp_meter.player_capacity = 4  # a warp core grants capacity (modules seed this in a real encounter)
	enc.warp_meter.add(true, enc.warp_meter.player_capacity)
	assert_bool(enc.warp_meter.can_jump(true)).is_true()
	enc.warp_meter.jump(true)
	assert_bool(enc.is_over()).is_true()
	assert_object(enc.defeated()).is_same(enc.opponent)  # the player won
	assert_int(enc.warp_meter.value).is_equal(0)  # expended


# The opponent can only Jump in a tug (Quick Match); Campaign never lets their warp win.
func test_opponent_jump_only_in_a_tug() -> void:
	var enc := _encounter()
	enc.warp_meter.opponent_capacity = 4
	enc.warp_meter.tug = false
	enc.warp_meter.value = -enc.warp_meter.opponent_capacity
	assert_bool(enc.warp_meter.can_jump(false)).is_false()
	enc.warp_meter.tug = true
	assert_bool(enc.warp_meter.can_jump(false)).is_true()
	enc.warp_meter.jump(false)
	assert_object(enc.defeated()).is_same(enc.player)  # the opponent won


# Without a warp core (zero capacity) a starship can't warp at all: matched warp banks nothing and Jump stays out.
func test_no_warp_without_a_core() -> void:
	var enc := _encounter()  # a fresh encounter carries no warp capacity
	enc.warp_meter.add(true, 10)
	assert_int(enc.warp_meter.value).is_equal(0)  # clamped to a zero capacity — nothing banks
	assert_bool(enc.warp_meter.can_jump(true)).is_false()


# Each side fills toward its own capacity: a six-bar core and a four-bar core Jump at different fills.
func test_warp_capacity_is_per_side() -> void:
	var enc := _encounter()
	enc.warp_meter.tug = true
	enc.warp_meter.player_capacity = 4
	enc.warp_meter.opponent_capacity = 6
	enc.warp_meter.add(true, 4)
	assert_bool(enc.warp_meter.can_jump(true)).is_true()  # full at 4
	enc.warp_meter.value = 0
	enc.warp_meter.add(false, 4)
	assert_bool(enc.warp_meter.can_jump(false)).is_false()  # 4 of 6, not yet
	enc.warp_meter.add(false, 2)
	assert_bool(enc.warp_meter.can_jump(false)).is_true()  # full at 6


# The Warp Core module grants warp capacity — guards the authored content the model depends on.
func test_warp_core_module_grants_capacity() -> void:
	var core := load("res://data/modules/warp_core_item_blueprint.tres") as ModuleBlueprint
	assert_int(core.stats.warp_capacity).is_equal(4)
