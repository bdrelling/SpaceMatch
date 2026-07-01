extends ResolutionTestCase
## Resolution tests for the amount types added alongside the core defaults: status-count, random, missing-stat,
## math, and modification amounts (plus the modify-stat action that records the in-flight change they read).


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
