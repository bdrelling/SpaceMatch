extends GdUnitTestSuite
## Resolution tests for the types added alongside the core defaults: ally-side and stat-selector targeting,
## status-count / random / missing / math amounts, the condition combinators (not/and/or/chance/compare), the
## cleanse and set-stat actions, the replace stack rule, and the [OnRemoveHook] / [OnExpireHook] lifecycle hooks.

## Chooser that picks the LAST candidate — proves selection routes through the seam, not a hardcoded pick.
class _PickLastChooser extends EffectChooser:
	func choose(candidates: Array[Entity], _source: Entity) -> Entity:
		return candidates[-1] if not candidates.is_empty() else null


func _stat(name: StringName) -> EntityStat:
	var stat := EntityStat.new()
	stat.name = name
	return stat


func _entity(health: int = 20, power: int = 0) -> Entity:
	var stats := EntityStats.new()
	stats.set_stat(_stat(&"health"), health)
	stats.set_maximum(_stat(&"health"), maxi(health, 20))
	stats.set_stat(_stat(&"power"), power)
	var entity := Entity.new()
	entity.current_stats = stats
	return entity


func _ctx(source: Entity, allies: Array[Entity], opponents: Array[Entity], rng_seed: int = 0, chooser: EffectChooser = null) -> ResolutionContext:
	return ResolutionContext.create(source, allies, opponents, rng_seed, chooser)


func _status(name: StringName, sign: Status.Sign = Status.Sign.NEGATIVE) -> Status:
	var status := Status.new()
	status.name = name
	status.sign = sign
	return status


func _damage_self(value: int) -> Effect:
	var amount := ConstantAmount.new()
	amount.value = value
	var action := ModifyStatAction.new()
	action.stat = _stat(&"health")
	action.tag = &"damage"
	action.subtracts = true
	action.amount = amount
	var effect := Effect.new()
	effect.target = SelfTarget.new()
	effect.action = action
	return effect


## A status that damages its holder by [param value] whenever [param hook] is raised on it.
func _reactor(name: StringName, hook: Hook, value: int) -> Status:
	var trigger := HookTrigger.new()
	trigger.hook = hook
	var triggered := TriggeredEffect.new()
	triggered.trigger = trigger
	triggered.effects = [_damage_self(value)]
	var status := _status(name)
	status.effects = [triggered]
	return status


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


# ── Amounts ───────────────────────────────────────

func test_status_count_amount_reads_the_sources_stacks() -> void:
	var source := _entity()
	StatusEngine.apply_status(source, _status(&"charge"), 3, null)
	var amount := StatusCountAmount.new()
	amount.status = &"charge"
	assert_int(amount.evaluate(_ctx(source, [source], []))).is_equal(3)


func test_status_count_amount_is_zero_without_the_status() -> void:
	var source := _entity()
	var amount := StatusCountAmount.new()
	amount.status = &"charge"
	assert_int(amount.evaluate(_ctx(source, [source], []))).is_equal(0)


func test_random_amount_stays_in_range_and_is_deterministic() -> void:
	var source := _entity()
	var amount := RandomAmount.new()
	amount.minimum = 5
	amount.maximum = 9
	var first := amount.evaluate(_ctx(source, [source], [], 7))
	var second := amount.evaluate(_ctx(source, [source], [], 7))
	assert_int(first).is_equal(second)
	assert_bool(first >= 5 and first <= 9).is_true()


func test_missing_stat_amount_is_the_shortfall() -> void:
	var source := _entity(8)  # health 8, max 20
	var amount := MissingStatAmount.new()
	amount.stat = _stat(&"health")
	assert_int(amount.evaluate(_ctx(source, [source], []))).is_equal(12)


func test_math_amount_combines_operands() -> void:
	var source := _entity(20, 4)
	var power := CurrentStatAmount.new()
	power.stat = _stat(&"power")
	var base := ConstantAmount.new()
	base.value = 3
	var sum := MathAmount.new()
	sum.left = base
	sum.right = power
	sum.operation = MathAmount.Operation.ADD
	assert_int(sum.evaluate(_ctx(source, [source], []))).is_equal(7)

	var doubled := MathAmount.new()
	doubled.left = power
	doubled.right = base
	doubled.operation = MathAmount.Operation.MULTIPLY
	assert_int(doubled.evaluate(_ctx(source, [source], []))).is_equal(12)


func test_modification_amount_reads_the_in_flight_change() -> void:
	var context := _ctx(_entity(), [], [])
	var modification := Modification.new()
	modification.amount = 7
	context.modification = modification
	assert_int(ModificationAmount.new().evaluate(context)).is_equal(7)


func test_modification_amount_is_zero_without_a_change() -> void:
	assert_int(ModificationAmount.new().evaluate(_ctx(_entity(), [], []))).is_equal(0)


func test_modify_stat_action_records_the_resolved_change_on_the_context() -> void:
	var foe := _entity(20)
	var context := _ctx(_entity(), [_entity()], [foe])
	var value := ConstantAmount.new()
	value.value = 10
	var damage := ModifyStatAction.new()
	damage.stat = _stat(&"health")
	damage.tag = &"damage"
	damage.subtracts = true
	damage.amount = value
	damage.resolve(context, foe)
	assert_int(context.modification.amount).is_equal(10)
	assert_int(ModificationAmount.new().evaluate(context)).is_equal(10)


# ── Condition combinators ─────────────────────────

func _has_status(target: Target, name: StringName) -> HasStatusCondition:
	var condition := HasStatusCondition.new()
	condition.target = target
	condition.status = name
	return condition


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


# ── Lifecycle hooks ───────────────────────────────

func test_remove_status_raises_on_remove_hook() -> void:
	var entity := _entity(20)
	entity.statuses.append(_stack(_reactor(&"watcher", OnRemoveHook.new(), 5), 1))
	StatusEngine.apply_status(entity, _status(&"poison"), 1, null)
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await EffectRuntime.new().remove_status(entity, &"poison", allies, opponents)
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(15)


func test_remove_status_skips_the_hook_when_nothing_was_there() -> void:
	var entity := _entity(20)
	entity.statuses.append(_stack(_reactor(&"watcher", OnRemoveHook.new(), 5), 1))
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await EffectRuntime.new().remove_status(entity, &"absent", allies, opponents)
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(20)


func test_phase_decay_to_zero_raises_on_expire_hook() -> void:
	var entity := _entity(20)
	entity.statuses.append(_stack(_reactor(&"watcher", OnExpireHook.new(), 4), 1))
	var fading := _status(&"shield")
	var decay := TimingDecayRule.new()
	decay.phase = &"turn_end"
	decay.quantity = 1
	fading.decay_rule = decay
	entity.statuses.append(_stack(fading, 1))
	var allies: Array[Entity] = [entity]
	var opponents: Array[Entity] = []
	await EffectRuntime.new().tick_phase(entity, allies, opponents, &"turn_end")
	assert_bool(StatusEngine.find_stack(entity, &"shield") == null).is_true()
	assert_int(entity.current_stats.get_stat(_stat(&"health"))).is_equal(16)


func _stack(status: Status, count: int) -> StatusStack:
	var stack := StatusStack.new()
	stack.status = status
	stack.count = count
	return stack
