extends GdUnitTestSuite
## Tests the reaction cascade: a stat change emits action hooks that statuses react to, reading the change off
## the context ([ModificationAmount] for "how much", [InstigatorTarget] for "who"), with depth capping runaway
## reflections so a reflection of a reflection terminates.

func _stat(name: StringName) -> EntityStat:
	var stat := EntityStat.new()
	stat.name = name
	return stat


func _entity(health: int = 20) -> Entity:
	var stats := EntityStats.new()
	stats.set_stat(_stat(&"health"), health)
	stats.set_maximum(_stat(&"health"), maxi(health, 20))
	var entity := Entity.new()
	entity.current_stats = stats
	return entity


func _constant(value: int) -> ConstantAmount:
	var amount := ConstantAmount.new()
	amount.value = value
	return amount


func _modify(tag: StringName, subtracts: bool, amount: Amount) -> ModifyStatAction:
	var action := ModifyStatAction.new()
	action.stat = _stat(&"health")
	action.tag = tag
	action.subtracts = subtracts
	action.amount = amount
	return action


func _stat_modified(tag: StringName) -> StatModifiedHook:
	var hook := StatModifiedHook.new()
	hook.tag = tag
	return hook


## A status that runs [param action] against [param target] whenever a stat change tagged [param tag] lands on
## its holder.
func _reactor(name: StringName, tag: StringName, target: Target, action: ModifyStatAction) -> StatusStack:
	var effect := Effect.new()
	effect.target = target
	effect.action = action
	var triggered := TriggeredEffect.new()
	var trigger := HookTrigger.new()
	trigger.hook = _stat_modified(tag)
	triggered.trigger = trigger
	triggered.effects = [effect]
	var status := Status.new()
	status.name = name
	status.effects = [triggered]
	var stack := StatusStack.new()
	stack.status = status
	stack.count = 1
	return stack


func _context(source: Entity, allies: Array[Entity], opponents: Array[Entity]) -> ResolutionContext:
	return ResolutionContext.create(source, allies, opponents, 0, null)


func test_reflect_deals_the_hit_back_to_the_attacker() -> void:
	var health := _stat(&"health")
	var attacker := _entity(20)
	var defender := _entity(20)
	defender.statuses.append(_reactor(&"reflect", &"damage", InstigatorTarget.new(),
		_modify(&"damage", true, ModificationAmount.new())))

	var allies: Array[Entity] = [attacker]
	var opponents: Array[Entity] = [defender]
	await _modify(&"damage", true, _constant(8)).resolve(_context(attacker, allies, opponents), defender)

	assert_int(defender.current_stats.get_stat(health)).is_equal(12)  # took the 8
	assert_int(attacker.current_stats.get_stat(health)).is_equal(12)  # reflected 8 back via the instigator


func test_undead_takes_damage_equal_to_the_heal() -> void:
	var health := _stat(&"health")
	var undead := _entity(10)
	undead.statuses.append(_reactor(&"undead", &"heal", SelfTarget.new(),
		_modify(&"damage", true, ModificationAmount.new())))

	var healer := _entity(20)
	var allies: Array[Entity] = [healer, undead]
	var opponents: Array[Entity] = []
	await _modify(&"heal", false, _constant(7)).resolve(_context(healer, allies, opponents), undead)

	assert_int(undead.current_stats.get_stat(health)).is_equal(10)  # +7 heal, -7 undead = net 0


func test_mutual_reflect_terminates() -> void:
	var health := _stat(&"health")
	var a := _entity(20)
	var b := _entity(20)
	a.statuses.append(_reactor(&"reflect", &"damage", InstigatorTarget.new(),
		_modify(&"damage", true, ModificationAmount.new())))
	b.statuses.append(_reactor(&"reflect", &"damage", InstigatorTarget.new(),
		_modify(&"damage", true, ModificationAmount.new())))

	var allies: Array[Entity] = [a]
	var opponents: Array[Entity] = [b]
	# a hits b for 5; reflections bounce until the depth cap stops them. Reaching the asserts proves it ended.
	await _modify(&"damage", true, _constant(5)).resolve(_context(a, allies, opponents), b)

	assert_int(a.current_stats.get_stat(health)).is_equal(0)
	assert_int(b.current_stats.get_stat(health)).is_equal(0)
