extends GdUnitTestSuite
## Smoke + contract tests for the effect_system data model: the [StatBlock] name-access contract, the
## game's [StarshipStats] subclass honoring it, enum sanity, and that the composable resource types
## construct and wire together.

## A minimal in-suite [StatBlock] subclass — stands in for a game's typed stats.
class _TestStats extends StatBlock:
	@export var hull: int = 10
	@export var shields: int = 5


func test_stat_block_get_and_set_by_name() -> void:
	var stats := _TestStats.new()
	assert_int(stats.get_stat(&"hull")).is_equal(10)
	stats.set_stat(&"shields", 8)
	assert_int(stats.get_stat(&"shields")).is_equal(8)


func test_stat_block_names_lists_declared_stats() -> void:
	var names := _TestStats.new().stat_names()
	assert_bool(names.has(&"hull")).is_true()
	assert_bool(names.has(&"shields")).is_true()


func test_starship_stats_honors_the_stat_block_contract() -> void:
	# The game's concrete stats subclass the engine's abstract StatBlock and inherit name access.
	var stats := StarshipStats.new()
	stats.power = 4
	assert_int(stats.get_stat(&"power")).is_equal(4)
	assert_bool(stats.stat_names().has(&"power")).is_true()


func test_entity_holds_stats_and_statuses() -> void:
	var entity := Entity.new()
	entity.base_stats = _TestStats.new()
	var poison := Status.new()
	poison.name = &"poison"
	poison.sign = Status.Sign.NEGATIVE
	var stack := StatusStack.new()
	stack.status = poison
	stack.count = 3
	entity.statuses.append(stack)
	assert_int(entity.statuses.size()).is_equal(1)
	assert_int(entity.statuses[0].count).is_equal(3)
	assert_bool(entity.statuses[0].status.name == &"poison").is_true()


func test_effect_composes_target_action_and_conditions() -> void:
	var effect := Effect.new()
	effect.target = OpponentTarget.new()
	var amount := ConstantAmount.new()
	amount.value = 5
	var damage := ModifyStatAction.new()
	damage.stat = &"health"
	damage.tag = &"damage"
	damage.subtracts = true
	damage.amount = amount
	effect.action = damage
	var gate := StatThresholdCondition.new()
	gate.target = SelfTarget.new()
	gate.stat = &"hull"
	gate.comparison = StatThresholdCondition.Comparison.GREATER
	gate.value = 0
	effect.conditions.append(gate)
	assert_bool(effect.action is ModifyStatAction).is_true()
	assert_int((effect.action as ModifyStatAction).amount.value).is_equal(5)
	assert_bool(effect.target is OpponentTarget).is_true()
	assert_int(effect.conditions.size()).is_equal(1)


func test_status_wires_rules_triggers_and_effects() -> void:
	var status := Status.new()
	status.stack_rule = StackStackRule.new()
	var decay := TimingDecayRule.new()
	decay.phase = &"turn_end"
	decay.quantity = 1
	status.decay_rule = decay
	var triggered := TriggeredEffect.new()
	triggered.trigger = CountTrigger.new()
	status.effects.append(triggered)
	assert_bool(status.stack_rule is StackRule).is_true()
	assert_bool(status.decay_rule is DecayRule).is_true()
	assert_bool(status.effects[0].trigger is Trigger).is_true()


func test_enums_have_expected_baseline_values() -> void:
	assert_int(Status.Sign.POSITIVE).is_equal(0)
	assert_int(Modifier.Operation.ADD).is_equal(0)
	assert_int(StatThresholdCondition.Comparison.LESS).is_equal(0)
