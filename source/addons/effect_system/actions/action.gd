class_name Action
extends Resource
## What an [Effect] does to its target. The subclasses below are defaults; games can add their own.

## Carries out the action against one already-resolved [param target] in [param context]. The base does
## nothing; subclasses override.
func resolve(_context: ResolutionContext, _target: Entity) -> void:
	pass
