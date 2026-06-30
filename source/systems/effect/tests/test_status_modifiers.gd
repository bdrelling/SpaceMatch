extends GdUnitTestSuite
## Tests [StatusModifiers.apply]: folding active-status [Modifier]s onto an [EntityStats], scaled by stack count.

func _stat(name: StringName) -> EntityStat:
	var stat := EntityStat.new()
	stat.name = name
	return stat


func _modifier(stat: EntityStat, operation: Modifier.Operation, amount: float) -> Modifier:
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


func _block(stat: EntityStat, value: int) -> EntityStats:
	var block := EntityStats.new()
	block.set_stat(stat, value)
	return block


func test_add_modifier_increases_stat() -> void:
	var damage := _stat(&"damage")
	var entity := _entity([_modifier(damage, Modifier.Operation.ADD, 2.0)])
	var into := _block(damage, 5)
	StatusModifiers.apply(entity, into)
	assert_int(into.get_stat(damage)).is_equal(7)


func test_add_modifier_scales_by_stack_count() -> void:
	var damage := _stat(&"damage")
	var entity := _entity([_modifier(damage, Modifier.Operation.ADD, 2.0)], 3)
	var into := _block(damage, 5)
	StatusModifiers.apply(entity, into)
	assert_int(into.get_stat(damage)).is_equal(11)


func test_multiply_modifier_scales_count_times() -> void:
	var armor := _stat(&"armor")
	var entity := _entity([_modifier(armor, Modifier.Operation.MULTIPLY, 2.0)], 2)
	var into := _block(armor, 3)
	StatusModifiers.apply(entity, into)
	assert_int(into.get_stat(armor)).is_equal(12)


func test_modifier_for_absent_stat_adds_it() -> void:
	var extra := _stat(&"extra")
	var entity := _entity([_modifier(extra, Modifier.Operation.ADD, 5.0)])
	var into := EntityStats.new()
	StatusModifiers.apply(entity, into)
	assert_int(into.get_stat(extra)).is_equal(5)


func test_multiple_statuses_fold_together() -> void:
	var damage := _stat(&"damage")
	var entity := _entity([_modifier(damage, Modifier.Operation.ADD, 2.0)])
	var second := Status.new()
	second.modifiers = [_modifier(damage, Modifier.Operation.ADD, 1.0)]
	var stack := StatusStack.new()
	stack.status = second
	stack.count = 1
	entity.statuses.append(stack)
	var into := EntityStats.new()
	StatusModifiers.apply(entity, into)
	assert_int(into.get_stat(damage)).is_equal(3)
