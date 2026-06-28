class_name StatThreshold
extends Condition
## True when [member target]'s [member stat] compares against [member value] per [member comparison].

enum Comparison {
	LESS,
	EQUAL,
	GREATER,
}

@export var target: Target
@export var stat: StringName
@export var comparison: Comparison = Comparison.GREATER
@export var value: int = 0
