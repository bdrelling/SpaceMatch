extends GdUnitTestSuite
## Tests [DrainResourceAction]: it subtracts the evaluated amount from each listed resource pool on the target,
## floors at zero, and skips pools the target doesn't hold.

func _resource(name: StringName) -> AbilityResource:
	var resource := AbilityResource.new()
	resource.name = name
	return resource


func _amount(value: int) -> ConstantAmount:
	var amount := ConstantAmount.new()
	amount.value = value
	return amount


func _context(source: Entity) -> ResolutionContext:
	return ResolutionContext.create(source, [], [], 0, null)


func test_drains_each_listed_pool_floored() -> void:
	var entity := Entity.new()
	var combat := _resource(&"combat")
	var science := _resource(&"science")
	ResourceEngine.grant(entity, combat, 5)
	ResourceEngine.grant(entity, science, 2)
	var action := DrainResourceAction.new()
	var to_drain: Array[AbilityResource] = [combat, science]
	action.resources = to_drain
	action.amount = _amount(3)
	action.resolve(_context(entity), entity)
	assert_int(ResourceEngine.amount_of(entity, combat)).is_equal(2)
	assert_int(ResourceEngine.amount_of(entity, science)).is_equal(0)  # floored, not negative


func test_non_positive_amount_drains_nothing() -> void:
	var entity := Entity.new()
	var combat := _resource(&"combat")
	ResourceEngine.grant(entity, combat, 4)
	var action := DrainResourceAction.new()
	var to_drain: Array[AbilityResource] = [combat]
	action.resources = to_drain
	action.amount = _amount(0)
	action.resolve(_context(entity), entity)
	assert_int(ResourceEngine.amount_of(entity, combat)).is_equal(4)


func test_null_target_is_noop() -> void:
	var action := DrainResourceAction.new()
	var to_drain: Array[AbilityResource] = [_resource(&"combat")]
	action.resources = to_drain
	action.amount = _amount(3)
	action.resolve(_context(null), null)  # must not crash
