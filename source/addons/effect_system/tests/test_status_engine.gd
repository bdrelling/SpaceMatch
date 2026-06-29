extends GdUnitTestSuite
## Tests [StatusEngine]: applying a status (honouring its [StackRule] and cap), removing it, and reducing a stack
## to zero.

func _status(name: StringName, cap: int = 0, rule: StackRule = null) -> Status:
	var status := Status.new()
	status.name = name
	status.cap = cap
	status.stack_rule = rule
	return status


func test_apply_creates_a_stack() -> void:
	var entity := Entity.new()
	var stack := StatusEngine.apply_status(entity, _status(&"poison"), 2, null)
	assert_int(entity.statuses.size()).is_equal(1)
	assert_int(stack.count).is_equal(2)


func test_stack_rule_sums_counts() -> void:
	var entity := Entity.new()
	var poison := _status(&"poison", 0, StackStackRule.new())
	StatusEngine.apply_status(entity, poison, 2, null)
	StatusEngine.apply_status(entity, poison, 3, null)
	assert_int(entity.statuses.size()).is_equal(1)
	assert_int(StatusEngine.find_stack(entity, &"poison").count).is_equal(5)


func test_cap_clamps_the_total() -> void:
	var entity := Entity.new()
	var poison := _status(&"poison", 4, StackStackRule.new())
	StatusEngine.apply_status(entity, poison, 3, null)
	StatusEngine.apply_status(entity, poison, 3, null)
	assert_int(StatusEngine.find_stack(entity, &"poison").count).is_equal(4)


func test_keep_highest_rule_takes_the_max() -> void:
	var entity := Entity.new()
	var buff := _status(&"buff", 0, KeepHighestStackRule.new())
	StatusEngine.apply_status(entity, buff, 5, null)
	StatusEngine.apply_status(entity, buff, 2, null)
	assert_int(StatusEngine.find_stack(entity, &"buff").count).is_equal(5)


func test_remove_status_drops_the_stack() -> void:
	var entity := Entity.new()
	StatusEngine.apply_status(entity, _status(&"poison"), 1, null)
	StatusEngine.remove_status(entity, &"poison")
	assert_int(entity.statuses.size()).is_equal(0)


func test_reduce_stack_removes_at_zero() -> void:
	var entity := Entity.new()
	var stack := StatusEngine.apply_status(entity, _status(&"poison"), 2, null)
	StatusEngine.reduce_stack(entity, stack, 2)
	assert_int(entity.statuses.size()).is_equal(0)


func test_reduce_stack_keeps_remainder() -> void:
	var entity := Entity.new()
	var stack := StatusEngine.apply_status(entity, _status(&"poison"), 3, null)
	StatusEngine.reduce_stack(entity, stack, 1)
	assert_int(stack.count).is_equal(2)
	assert_int(entity.statuses.size()).is_equal(1)
