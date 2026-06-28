extends GdUnitTestSuite
## Resolution tests for the effect engine: amount evaluation, target selection (including seeded randomness
## and the chooser seam), the stat-aware damage pipeline (amplify / mitigate / absorb / clamp and their
## fixed order), healing, and condition gating through [method Effect.resolve].

## A stand-in for a game's typed stats, with the fields the damage pipeline reads.
class _TestStats extends StatBlock:
	@export var health: int = 20
	@export var max_health: int = 20
	@export var armor: int = 0
	@export var shields: int = 0
	@export var power: int = 0


## Chooser that picks the LAST candidate — proves selection routes through the seam, not a hardcoded pick.
class _PickLastChooser extends EffectChooser:
	func choose(candidates: Array[Entity], _source: Entity) -> Entity:
		return candidates[-1] if not candidates.is_empty() else null


func _entity(health: int = 20, armor: int = 0, shields: int = 0, power: int = 0) -> Entity:
	var entity := Entity.new()
	var stats := _TestStats.new()
	stats.health = health
	stats.max_health = maxi(health, stats.max_health)
	stats.armor = armor
	stats.shields = shields
	stats.power = power
	entity.current_stats = stats
	return entity


func _damage_status(steps: Array[DamageStep]) -> StatusStack:
	var status := Status.new()
	status.damage_steps = steps
	var stack := StatusStack.new()
	stack.status = status
	stack.count = 1
	return stack


func _context(source: Entity, enemies: Array[Entity], rng_seed: int = 0, chooser: EffectChooser = null) -> ResolutionContext:
	var allies: Array[Entity] = [source]
	return ResolutionContext.create(source, allies, enemies, rng_seed, chooser)


# ── Amounts ───────────────────────────────────────

func test_constant_amount_evaluates_to_its_value() -> void:
	var amount := ConstantAmount.new()
	amount.value = 7
	assert_int(amount.evaluate(_context(_entity(), []))).is_equal(7)


func test_stat_amount_reads_the_source_stat() -> void:
	var source := _entity(20, 0, 0, 4)
	var amount := StatAmount.new()
	amount.stat = &"power"
	assert_int(amount.evaluate(_context(source, []))).is_equal(4)


# ── Targeting ─────────────────────────────────────

func test_self_target_returns_the_source() -> void:
	var source := _entity()
	var result := SelfTarget.new().resolve(_context(source, []))
	assert_int(result.size()).is_equal(1)
	assert_bool(result[0] == source).is_true()


func test_enemy_target_returns_first_foe() -> void:
	var foe := _entity()
	var enemies: Array[Entity] = [foe, _entity()]
	var result := EnemyTarget.new().resolve(_context(_entity(), enemies))
	assert_bool(result[0] == foe).is_true()


func test_all_enemies_target_returns_every_foe() -> void:
	var enemies: Array[Entity] = [_entity(), _entity(), _entity()]
	assert_int(AllEnemiesTarget.new().resolve(_context(_entity(), enemies)).size()).is_equal(3)


func test_random_enemy_target_is_deterministic_for_a_seed() -> void:
	var enemies: Array[Entity] = [_entity(), _entity(), _entity(), _entity()]
	var first := RandomEnemyTarget.new().resolve(_context(_entity(), enemies, 123))
	var second := RandomEnemyTarget.new().resolve(_context(_entity(), enemies, 123))
	assert_bool(first[0] == second[0]).is_true()
	assert_bool(first[0] in enemies).is_true()


func test_chosen_target_routes_through_the_chooser() -> void:
	var enemies: Array[Entity] = [_entity(), _entity(), _entity()]
	var picked: Array[Entity] = await ChosenTarget.new().resolve(_context(_entity(), enemies, 0, _PickLastChooser.new()))
	assert_bool(picked[0] == enemies[-1]).is_true()


# ── Damage pipeline ───────────────────────────────

func test_deal_damage_reduces_vitality() -> void:
	var foe := _entity(20)
	_deal(10, _entity(), foe)
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(10)


func test_flat_mitigation_subtracts_armor() -> void:
	var foe := _entity(20, 3)
	foe.statuses.append(_damage_status([_mitigation(&"armor")]))
	_deal(10, _entity(), foe)
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(13)  # 10 - 3 armor = 7 damage


func test_absorb_drains_the_pool_and_writes_it_back() -> void:
	var foe := _entity(20, 0, 3)
	foe.statuses.append(_damage_status([_absorb(&"shields")]))
	_deal(10, _entity(), foe)
	assert_int(foe.current_stats.get_stat(&"shields")).is_equal(0)   # pool spent
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(13)   # 7 carried through


func test_multiplier_amplifies_and_floors() -> void:
	var foe := _entity(20)
	foe.statuses.append(_damage_status([_multiplier(1.5)]))
	_deal(3, _entity(), foe)
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(16)   # floor(3 * 1.5) = 4


func test_clamp_caps_a_hit() -> void:
	var foe := _entity(20)
	foe.statuses.append(_damage_status([_clamp(1)]))
	_deal(10, _entity(), foe)
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(19)   # capped to 1


func test_pipeline_applies_phases_in_fixed_order() -> void:
	var foe := _entity(20, 2, 3)
	# Authored out of order on purpose: absorb, then mitigate, then amplify.
	foe.statuses.append(_damage_status([_absorb(&"shields"), _mitigation(&"armor"), _multiplier(1.5)]))
	_deal(10, _entity(), foe)
	# 10 -> amplify x1.5 = 15 -> armor 2 = 13 -> shields 3 absorb = 10 damage.
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(10)
	assert_int(foe.current_stats.get_stat(&"shields")).is_equal(0)


func test_damage_never_goes_below_zero() -> void:
	var foe := _entity(20, 99)
	foe.statuses.append(_damage_status([_mitigation(&"armor")]))
	_deal(5, _entity(), foe)
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(20)   # fully mitigated


func test_outgoing_multiplier_on_the_source_weakens_damage() -> void:
	var source := _entity()
	source.statuses.append(_damage_status([_multiplier(0.5)]))   # Weak on the attacker
	var foe := _entity(20)
	_deal(10, source, foe)
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(15)   # 10 * 0.5 = 5


# ── Healing ───────────────────────────────────────

func test_heal_restores_and_caps_at_max() -> void:
	var ally := _entity(5)  # max_health stays 20
	var heal := Heal.new()
	heal.amount = _const(8)
	heal.resolve(_context(_entity(), []), ally)
	assert_int(ally.current_stats.get_stat(&"health")).is_equal(13)

	var topped := _entity(18)
	heal.resolve(_context(_entity(), []), topped)
	assert_int(topped.current_stats.get_stat(&"health")).is_equal(20)  # capped, not 26


# ── Effect gating ─────────────────────────────────

func test_effect_skips_action_when_a_condition_fails() -> void:
	var foe := _entity(20)
	var effect := _damage_effect(10)
	var gate := StatThreshold.new()
	gate.target = SelfTarget.new()
	gate.stat = &"health"
	gate.comparison = StatThreshold.Comparison.LESS  # source health < 0 is false
	gate.value = 0
	effect.conditions.append(gate)
	await effect.resolve(_context(_entity(), [foe]))
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(20)   # blocked


func test_effect_runs_action_when_conditions_hold() -> void:
	var foe := _entity(20)
	var effect := _damage_effect(10)
	await effect.resolve(_context(_entity(), [foe]))
	assert_int(foe.current_stats.get_stat(&"health")).is_equal(10)


# ── helpers ───────────────────────────────────────

func _const(value: int) -> ConstantAmount:
	var amount := ConstantAmount.new()
	amount.value = value
	return amount


func _mitigation(stat: StringName) -> FlatMitigationStep:
	var step := FlatMitigationStep.new()
	step.stat = stat
	return step


func _absorb(stat: StringName) -> AbsorbStep:
	var step := AbsorbStep.new()
	step.stat = stat
	return step


func _multiplier(factor: float) -> MultiplierStep:
	var step := MultiplierStep.new()
	step.factor = factor
	return step


func _clamp(maximum: int) -> ClampStep:
	var step := ClampStep.new()
	step.maximum = maximum
	return step


func _damage_effect(value: int) -> Effect:
	var effect := Effect.new()
	effect.target = EnemyTarget.new()
	var damage := DealDamage.new()
	damage.amount = _const(value)
	damage.damage_type = &"kinetic"
	effect.action = damage
	return effect


func _deal(value: int, source: Entity, target: Entity) -> void:
	var damage := DealDamage.new()
	damage.amount = _const(value)
	damage.damage_type = &"kinetic"
	damage.resolve(_context(source, [target]), target)
