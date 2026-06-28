class_name ConstantAmount
extends Amount
## A fixed value.

@export var value: int = 0


func evaluate(_context: ResolutionContext) -> int:
	return value
