class_name Modifier
extends Resource
## A stat adjustment applied to an entity while its owning [Status] is active.

## How [member amount] combines with the stat.
enum Operation {
	ADD,       ## Flat delta added to the stat.
	MULTIPLY,  ## Scales the stat.
}

@export var stat: EntityStat
@export var operation: Operation = Operation.ADD
@export var amount: float = 0.0
