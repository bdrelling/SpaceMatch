extends GdUnitTestSuite
## Tests [AbilityRunner.run]: every effect resolves in order, and the runner never touches [member Ability.cost].

class _SpyAction extends Action:
	var ran: int = 0
	func resolve(_context: ResolutionContext, _target: Entity) -> void:
		ran += 1


func _effect(action: Action) -> Effect:
	var effect := Effect.new()
	effect.target = SelfTarget.new()
	effect.action = action
	return effect


func _context(source: Entity) -> ResolutionContext:
	var allies: Array[Entity] = [source]
	var opponents: Array[Entity] = []
	return ResolutionContext.create(source, allies, opponents, 0, null)


func test_runs_all_effects() -> void:
	var first := _SpyAction.new()
	var second := _SpyAction.new()
	var ability := Ability.new()
	ability.effects = [_effect(first), _effect(second)]
	await AbilityRunner.run(ability, _context(Entity.new()))
	assert_int(first.ran).is_equal(1)
	assert_int(second.ran).is_equal(1)


func test_ignores_cost() -> void:
	var ability := Ability.new()
	ability.cost = 99
	ability.effects = []
	await AbilityRunner.run(ability, _context(Entity.new()))
	assert_int(ability.cost).is_equal(99)
