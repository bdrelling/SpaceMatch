extends GdUnitTestSuite
## Tests [ResourceEngine]: holding, granting (with cap), affording, and spending [AbilityResource] pools — and that
## costs and pools match by resource name.

func _resource(name: StringName, maximum: int = 0) -> AbilityResource:
	var resource := AbilityResource.new()
	resource.name = name
	resource.maximum = maximum
	return resource


func _cost(resource: AbilityResource, amount: int) -> ResourceCost:
	var cost := ResourceCost.new()
	cost.resource = resource
	cost.amount = amount
	return cost


func test_grant_creates_pool_and_accumulates() -> void:
	var entity := Entity.new()
	var energy := _resource(&"energy")
	ResourceEngine.grant(entity, energy, 3)
	ResourceEngine.grant(entity, energy, 2)
	assert_int(ResourceEngine.amount_of(entity, energy)).is_equal(5)


func test_grant_clamps_to_maximum() -> void:
	var entity := Entity.new()
	var energy := _resource(&"energy", 4)
	ResourceEngine.grant(entity, energy, 10)
	assert_int(ResourceEngine.amount_of(entity, energy)).is_equal(4)


func test_amount_of_is_zero_when_absent() -> void:
	assert_int(ResourceEngine.amount_of(Entity.new(), _resource(&"energy"))).is_equal(0)


func test_can_afford_checks_every_cost() -> void:
	var entity := Entity.new()
	var energy := _resource(&"energy")
	var ammo := _resource(&"ammo")
	ResourceEngine.grant(entity, energy, 5)
	ResourceEngine.grant(entity, ammo, 1)
	var costs: Array[ResourceCost] = [_cost(energy, 3), _cost(ammo, 2)]
	assert_bool(ResourceEngine.can_afford(entity, costs)).is_false()  # ammo short
	ResourceEngine.grant(entity, ammo, 1)
	assert_bool(ResourceEngine.can_afford(entity, costs)).is_true()


func test_spend_reduces_pools() -> void:
	var entity := Entity.new()
	var energy := _resource(&"energy")
	ResourceEngine.grant(entity, energy, 5)
	var costs: Array[ResourceCost] = [_cost(energy, 3)]
	ResourceEngine.spend(entity, costs)
	assert_int(ResourceEngine.amount_of(entity, energy)).is_equal(2)


func test_resources_match_by_name_across_instances() -> void:
	# A cost and a pool that name the same resource line up even as different AbilityResource instances.
	var entity := Entity.new()
	ResourceEngine.grant(entity, _resource(&"energy"), 5)
	var costs: Array[ResourceCost] = [_cost(_resource(&"energy"), 4)]
	assert_bool(ResourceEngine.can_afford(entity, costs)).is_true()
