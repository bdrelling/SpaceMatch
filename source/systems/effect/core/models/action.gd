class_name Action
extends Resource
## What an [Effect] does to its target. The subclasses below are defaults; games can add their own.


## Carries out the action against one already-resolved [param target] in [param context]. The base does
## nothing; subclasses override.
func resolve(_context: ResolutionContext, _target: Entity) -> void:
	pass


## A short, human description of this action for an ability tooltip — e.g. "Deal 5 damage". The base returns
## empty; player-facing actions override it. Kept here so [method Ability.describe] can join effects without
## type-checking each action.
func describe() -> String:
	return ""
