class_name StackPlacement
extends Resource
## Where a stack sits in a grid inventory: its anchor cell plus quarter-turn rotation.

@export var anchor: Vector2i

## Quarter turns clockwise (0–3) applied to the footprint.
@export var rotation_steps: int

func _init(_anchor: Vector2i = Vector2i.ZERO, _rotation_steps: int = 0) -> void:
	anchor = _anchor
	rotation_steps = _rotation_steps
