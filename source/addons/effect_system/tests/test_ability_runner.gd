extends GdUnitTestSuite
## Tests [AbilityRunner.run]: it pays the ability's [ResourceCost]s then resolves every effect in order, and runs
## nothing (returning false) when the source can't afford it.

class _SpyAction extends Action:
	var ran: int = 0
	func resolve(_context: ResolutionContext, _target: Entity) -> void:
		ran += 1


func _effect(action: Action) -> Effect:
	var effect := Effect.new()
	effect.target = SelfTarget.new()
	effect.action = action
	return effect


func _resource(name: StringName) -> AbilityResource:
	var resource := AbilityResource.new()
	resource.name = name
	return resource


func _cost(resource: AbilityResource, amount: int) -> ResourceCost:
	var cost := ResourceCost.new()
	cost.resource = resource
	cost.amount = amount
	return cost


func _context(source: Entity) -> ResolutionContext:
	var allies: Array[Entity] = [source]
	var opponents: Array[Entity] = []
	return ResolutionContext.create(source, allies, opponents, 0, null)


func test_runs_all_effects_when_free() -> void:
	var first := _SpyAction.new()
	var second := _SpyAction.new()
	var ability := Ability.new()
	ability.effects = [_effect(first), _effect(second)]
	var ran: bool = await AbilityRunner.run(ability, _context(Entity.new()))
	assert_bool(ran).is_true()
	assert_int(first.ran).is_equal(1)
	assert_int(second.ran).is_equal(1)


func test_pays_cost_then_runs() -> void:
	var energy := _resource(&"energy")
	var source := Entity.new()
	ResourceEngine.grant(source, energy, 5)
	var spy := _SpyAction.new()
	var ability := Ability.new()
	ability.costs = [_cost(energy, 3)]
	ability.effects = [_effect(spy)]
	var ran: bool = await AbilityRunner.run(ability, _context(source))
	assert_bool(ran).is_true()
	assert_int(spy.ran).is_equal(1)
	assert_int(ResourceEngine.amount_of(source, energy)).is_equal(2)


func test_skips_when_unaffordable() -> void:
	var energy := _resource(&"energy")
	var source := Entity.new()
	ResourceEngine.grant(source, energy, 1)
	var spy := _SpyAction.new()
	var ability := Ability.new()
	ability.costs = [_cost(energy, 3)]
	ability.effects = [_effect(spy)]
	var ran: bool = await AbilityRunner.run(ability, _context(source))
	assert_bool(ran).is_false()
	assert_int(spy.ran).is_equal(0)
	assert_int(ResourceEngine.amount_of(source, energy)).is_equal(1)  # not spent
