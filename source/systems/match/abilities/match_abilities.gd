class_name MatchAbilities
extends RefCounted
## Builders for the game's standard [Ability]s — each pairs a cost (matched tiles of one resource) with one match
## [Action] targeting the user or the opponent. Keeps [Starship] and the tests free of the Effect/Target/Cost
## boilerplate; author bespoke abilities as a `.tres` or by assembling an [Ability] directly.


## An [Ability] named [param name], costing [param amount] of [param resource], that runs [param action] against
## the user when [param self_targeted], otherwise the opponent.
static func _build(name: String, resource: AbilityResource, amount: int, action: Action, self_targeted: bool) -> Ability:
	var ability := Ability.new()
	ability.name = name
	var cost := ResourceCost.new()
	cost.resource = resource
	cost.amount = amount
	ability.costs = [cost]
	var effect := Effect.new()
	effect.target = SelfTarget.new() if self_targeted else AllOpponentsTarget.new()
	effect.action = action
	ability.effects = [effect]
	return ability


## Deal [param damage] to the opponent.
static func attack(name: String, resource: AbilityResource, cost: int, damage: int) -> Ability:
	return _build(name, resource, cost, AttackAction.make(damage), false)


## Gain [param amount] shield.
static func shield(name: String, resource: AbilityResource, cost: int, amount: int) -> Ability:
	return _build(name, resource, cost, ShieldAction.make(amount), true)


## Arm a dodge (negate the next attack).
static func dodge(name: String, resource: AbilityResource, cost: int) -> Ability:
	return _build(name, resource, cost, DodgeAction.make(), true)


## Drain [param amount] from each of the opponent's stat resources.
static func drain(name: String, resource: AbilityResource, cost: int, amount: int) -> Ability:
	return _build(name, resource, cost, DrainAction.make(amount), false)


## Raise the user's tile-damage bonus by [param amount] (stacks).
static func damage_buff(name: String, resource: AbilityResource, cost: int, amount: int) -> Ability:
	return _build(name, resource, cost, DamageBuffAction.make(amount), true)


## Disable one of the opponent's modules for [param turns] turns.
static func disable(name: String, resource: AbilityResource, cost: int, turns: int) -> Ability:
	return _build(name, resource, cost, DisableAction.make(turns), false)
