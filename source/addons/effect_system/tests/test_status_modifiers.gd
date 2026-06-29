extends GdUnitTestSuite
## Tests [StatusModifiers.apply]: folding active-status [Modifier]s onto a game-supplied [StatBlock], scaled by
## stack count, leaving undeclared stats untouched and preserving each stat's type.

class _TestStats extends StatBlock:
	@export var damage: int = 0
	@export var armor: int = 0
	@export var speed: float = 0.0


func _modifier(stat: StringName, operation: Modifier.Operation, amount: float) -> Modifier:
	var modifier := Modifier.new()
	modifier.stat = stat
	modifier.operation = operation
	modifier.amount = amount
	return modifier


func _entity(modifiers: Array[Modifier], count: int = 1) -> Entity:
	var status := Status.new()
	status.modifiers = modifiers
	var stack := StatusStack.new()
	stack.status = status
	stack.count = count
	var entity := Entity.new()
	entity.statuses.append(stack)
	return entity


func test_add_modifier_increases_stat() -> void:
	var entity := _entity([_modifier(&"damage", Modifier.Operation.ADD, 2.0)])
	var into := _TestStats.new()
	into.damage = 5
	StatusModifiers.apply(entity, into)
	assert_int(into.damage).is_equal(7)


func test_add_modifier_scales_by_stack_count() -> void:
	var entity := _entity([_modifier(&"damage", Modifier.Operation.ADD, 2.0)], 3)
	var into := _TestStats.new()
	into.damage = 5
	StatusModifiers.apply(entity, into)
	assert_int(into.damage).is_equal(11)  # 5 + 2 * 3


func test_multiply_modifier_scales_count_times() -> void:
	var entity := _entity([_modifier(&"armor", Modifier.Operation.MULTIPLY, 2.0)], 2)
	var into := _TestStats.new()
	into.armor = 3
	StatusModifiers.apply(entity, into)
	assert_int(into.armor).is_equal(12)  # 3 * 2^2


func test_unknown_stat_is_skipped() -> void:
	var entity := _entity([_modifier(&"nonexistent", Modifier.Operation.ADD, 5.0)])
	var into := _TestStats.new()
	StatusModifiers.apply(entity, into)  # must not error
	assert_int(into.damage).is_equal(0)


func test_float_stat_keeps_its_type() -> void:
	var entity := _entity([_modifier(&"speed", Modifier.Operation.ADD, 1.5)])
	var into := _TestStats.new()
	into.speed = 2.0
	StatusModifiers.apply(entity, into)
	assert_float(into.speed).is_equal_approx(3.5, 0.001)


func test_multiple_statuses_fold_together() -> void:
	var entity := _entity([_modifier(&"damage", Modifier.Operation.ADD, 2.0)])
	var second := Status.new()
	second.modifiers = [_modifier(&"damage", Modifier.Operation.ADD, 1.0)]
	var stack := StatusStack.new()
	stack.status = second
	stack.count = 1
	entity.statuses.append(stack)
	var into := _TestStats.new()
	StatusModifiers.apply(entity, into)
	assert_int(into.damage).is_equal(3)
