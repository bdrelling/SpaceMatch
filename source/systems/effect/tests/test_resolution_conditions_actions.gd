extends ResolutionTestCase
## Resolution tests for the condition combinators (not/and/or/chance/compare) and the actions added alongside
## the core defaults: the cleanse-by-sign and set-stat actions, and the replace stack rule.


func _has_status(target: Target, name: StringName) -> HasStatusCondition:
	var condition := HasStatusCondition.new()
	condition.target = target
	condition.status = name
	return condition


# ── Condition combinators ─────────────────────────


func test_not_condition_negates() -> void:
	var source := _entity()
	StatusEngine.apply_status(source, _status(&"poison"), 1, null)
	var inner := _has_status(SelfTarget.new(), &"poison")
	var negated := NotCondition.new()
	negated.condition = inner
	assert_bool(negated.holds(_ctx(source, [source], []))).is_false()
	negated.condition = _has_status(SelfTarget.new(), &"absent")
	assert_bool(negated.holds(_ctx(source, [source], []))).is_true()


func test_and_condition_requires_every_member() -> void:
	var source := _entity()
	StatusEngine.apply_status(source, _status(&"poison"), 1, null)
	var both := AndCondition.new()
	both.conditions = [_has_status(SelfTarget.new(), &"poison"), _has_status(SelfTarget.new(), &"bleed")]
	assert_bool(both.holds(_ctx(source, [source], []))).is_false()
	StatusEngine.apply_status(source, _status(&"bleed"), 1, null)
	assert_bool(both.holds(_ctx(source, [source], []))).is_true()


func test_or_condition_needs_one_member() -> void:
	var source := _entity()
	StatusEngine.apply_status(source, _status(&"bleed"), 1, null)
	var either := OrCondition.new()
	either.conditions = [_has_status(SelfTarget.new(), &"poison"), _has_status(SelfTarget.new(), &"bleed")]
	assert_bool(either.holds(_ctx(source, [source], []))).is_true()
	var neither := OrCondition.new()
	neither.conditions = [_has_status(SelfTarget.new(), &"poison")]
	assert_bool(neither.holds(_ctx(source, [source], []))).is_false()


func test_chance_condition_honours_its_bounds() -> void:
	var source := _entity()
	var always := ChanceCondition.new()
	always.chance = 1.0
	assert_bool(always.holds(_ctx(source, [source], [], 1))).is_true()
	var never := ChanceCondition.new()
	never.chance = 0.0
	assert_bool(never.holds(_ctx(source, [source], [], 1))).is_false()


func test_compare_stats_condition_compares_two_targets() -> void:
	var source := _entity(20, 5)
	var foe := _entity(20, 2)
	var stronger := CompareStatsCondition.new()
	stronger.target = SelfTarget.new()
	stronger.other = OpponentTarget.new()
	stronger.stat = _stat(&"power")
	stronger.comparison = CompareStatsCondition.Comparison.GREATER
	assert_bool(stronger.holds(_ctx(source, [source], [foe]))).is_true()
	stronger.comparison = CompareStatsCondition.Comparison.LESS
	assert_bool(stronger.holds(_ctx(source, [source], [foe]))).is_false()


# ── Actions ───────────────────────────────────────


func test_remove_statuses_by_sign_strips_only_the_matching_sign() -> void:
	var entity := _entity()
	StatusEngine.apply_status(entity, _status(&"poison", Status.Sign.NEGATIVE), 1, null)
	StatusEngine.apply_status(entity, _status(&"bleed", Status.Sign.NEGATIVE), 1, null)
	StatusEngine.apply_status(entity, _status(&"blessing", Status.Sign.POSITIVE), 1, null)
	var cleanse := RemoveStatusesBySignAction.new()
	cleanse.sign = Status.Sign.NEGATIVE
	cleanse.resolve(_ctx(entity, [entity], []), entity)
	assert_int(entity.statuses.size()).is_equal(1)
	assert_bool(StatusEngine.find_stack(entity, &"blessing") != null).is_true()


func test_set_stat_action_writes_an_absolute_value() -> void:
	var entity := _entity(20)
	var value := ConstantAmount.new()
	value.value = 1
	var action := SetStatAction.new()
	action.stat = _stat(&"health")
	action.amount = value
	action.resolve(_ctx(entity, [entity], []), entity)
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(1)


# ── Replace stack rule ────────────────────────────


func test_replace_stack_rule_overwrites_the_count() -> void:
	var entity := _entity()
	var status := _status(&"mark")
	status.stack_rule = ReplaceStackRule.new()
	StatusEngine.apply_status(entity, status, 5, null)
	StatusEngine.apply_status(entity, status, 2, null)
	assert_int(StatusEngine.find_stack(entity, &"mark").count).is_equal(2)
