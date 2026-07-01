class_name ResolutionTestCase
extends GdUnitTestSuite
## Shared fixtures for the resolution-additions suites (targeting, amounts, conditions/actions, hooks).
## Holds only helper builders — no [code]test_[/code] methods — so gdUnit4's discovery skips it and it never
## runs as a suite of its own. Each concrete suite [code]extends ResolutionTestCase[/code].


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


func _stack(status: Status, count: int) -> StatusStack:
	var stack := StatusStack.new()
	stack.status = status
	stack.count = count
	return stack
