extends ResolutionTestCase
## Resolution tests for ally-side targeting and the stat-selector targets added alongside the core defaults.


## Chooser that picks the LAST candidate — proves selection routes through the seam, not a hardcoded pick.
class _PickLastChooser:
	extends EffectChooser

	func choose(candidates: Array[Entity], _source: Entity) -> Entity:
		return candidates[-1] if not candidates.is_empty() else null


# ── Ally-side targeting ───────────────────────────


func test_all_allies_target_returns_the_whole_side() -> void:
	var source := _entity()
	var allies: Array[Entity] = [source, _entity(), _entity()]
	assert_int(AllAlliesTarget.new().resolve(_ctx(source, allies, [])).size()).is_equal(3)


func test_random_ally_target_is_deterministic_for_a_seed() -> void:
	var source := _entity()
	var allies: Array[Entity] = [source, _entity(), _entity(), _entity()]
	var first := RandomAllyTarget.new().resolve(_ctx(source, allies, [], 99))
	var second := RandomAllyTarget.new().resolve(_ctx(source, allies, [], 99))
	assert_bool(first[0] == second[0]).is_true()
	assert_bool(first[0] in allies).is_true()


func test_chosen_ally_target_routes_through_the_chooser() -> void:
	var source := _entity()
	var allies: Array[Entity] = [source, _entity(), _entity()]
	var picked: Array[Entity] = await ChosenAllyTarget.new().resolve(_ctx(source, allies, [], 0, _PickLastChooser.new()))
	assert_bool(picked[0] == allies[-1]).is_true()


func test_all_entities_target_returns_both_sides() -> void:
	var source := _entity()
	var allies: Array[Entity] = [source, _entity()]
	var opponents: Array[Entity] = [_entity(), _entity(), _entity()]
	assert_int(AllEntitiesTarget.new().resolve(_ctx(source, allies, opponents)).size()).is_equal(5)


# ── EntityStat-selector targeting ───────────────────────


func test_lowest_stat_target_picks_the_smallest() -> void:
	var source := _entity()
	var wounded := _entity(4)
	var allies: Array[Entity] = [source, _entity(18), wounded, _entity(12)]
	var target := LowestStatTarget.new()
	target.from = AllAlliesTarget.new()
	target.stat = _stat(&"health")
	var picked := await target.resolve(_ctx(source, allies, []))
	assert_bool(picked[0] == wounded).is_true()


func test_highest_stat_target_picks_the_largest() -> void:
	var source := _entity()
	var toughest := _entity(30)
	var opponents: Array[Entity] = [_entity(10), toughest, _entity(22)]
	var target := HighestStatTarget.new()
	target.from = AllOpponentsTarget.new()
	target.stat = _stat(&"health")
	var picked := await target.resolve(_ctx(source, [source], opponents))
	assert_bool(picked[0] == toughest).is_true()
