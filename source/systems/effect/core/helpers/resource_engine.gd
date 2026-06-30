class_name ResourceEngine
extends RefCounted
## Reads and changes an [Entity]'s [ResourcePool]s — the spendable [AbilityResource] amounts it holds. Ability costs
## are paid here: check the entity can afford its [ResourceCost]s, then spend them. Pools and costs match by the
## resource's name, so they line up even across separate [AbilityResource] instances. The game refills pools with
## [method grant] as it collects.


## The entity's pool for [param resource] (matched by name), or null when it holds none.
static func pool_for(entity: Entity, resource: AbilityResource) -> ResourcePool:
	if entity == null or resource == null:
		return null
	for pool in entity.resources:
		if pool != null and pool.resource != null and pool.resource.name == resource.name:
			return pool
	return null


## How much of [param resource] [param entity] currently holds.
static func amount_of(entity: Entity, resource: AbilityResource) -> int:
	var pool := pool_for(entity, resource)
	return pool.amount if pool != null else 0


## Whether [param entity] holds enough to pay every cost in [param costs].
static func can_afford(entity: Entity, costs: Array[ResourceCost]) -> bool:
	for cost in costs:
		if cost == null or cost.resource == null:
			continue
		if amount_of(entity, cost.resource) < cost.amount:
			return false
	return true


## Subtracts each cost in [param costs] from [param entity]'s pools (floored at zero). Assumes affordability was
## already checked.
static func spend(entity: Entity, costs: Array[ResourceCost]) -> void:
	for cost in costs:
		if cost == null or cost.resource == null:
			continue
		var pool := pool_for(entity, cost.resource)
		if pool != null:
			pool.amount = maxi(0, pool.amount - cost.amount)


## Adds [param amount] of [param resource] to [param entity], creating its pool if absent and clamping to the
## pool's [member ResourcePool.maximum] (0 = unlimited).
static func grant(entity: Entity, resource: AbilityResource, amount: int) -> void:
	if entity == null or resource == null:
		return
	var pool := pool_for(entity, resource)
	if pool == null:
		pool = ResourcePool.new()
		pool.resource = resource
		entity.resources.append(pool)
	pool.amount += amount
	if pool.maximum > 0:
		pool.amount = mini(pool.amount, pool.maximum)
	pool.amount = maxi(0, pool.amount)


## Subtracts [param amount] of [param resource] from [param entity] (floored at zero). A no-op when the entity
## holds no pool for it — the symmetric counterpart of [method grant], used by drain/siphon effects.
static func drain(entity: Entity, resource: AbilityResource, amount: int) -> void:
	if entity == null or resource == null:
		return
	var pool := pool_for(entity, resource)
	if pool != null:
		pool.amount = maxi(0, pool.amount - amount)
