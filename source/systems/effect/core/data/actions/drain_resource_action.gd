class_name DrainResourceAction
extends Action
## Subtracts an amount from each of the target's named resource pools (floored at zero) — a drain/siphon. The
## amount is computed once and applied to every listed resource; a pool the target doesn't hold is skipped. The
## counterpart of granting: where [ModifyStatAction] changes a stat, this changes a spendable pool on the target.

## The resources to drain from the target. The same amount is taken from each.
@export var resources: Array[AbilityResource] = []
## How much to drain from each resource. Non-positive (or null) drains nothing.
@export var amount: Amount


## Drains the evaluated [member amount] from each of [member resources] on [param target] via [ResourceEngine].
func resolve(context: ResolutionContext, target: Entity) -> void:
	if target == null:
		return
	var value: int = amount.evaluate(context) if amount != null else 0
	if value <= 0:
		return
	for resource: AbilityResource in resources:
		if resource != null:
			ResourceEngine.drain(target, resource, value)
