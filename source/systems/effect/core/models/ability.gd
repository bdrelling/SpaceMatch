class_name Ability
extends Resource
## A player-facing ability: a named bundle of [Effect]s run in order, paid for with [ResourceCost]s.

@export var name: StringName
## What using this ability spends; empty is free. Paid by [AbilityRunner] against the source's [ResourcePool]s.
@export var costs: Array[ResourceCost] = []
@export var effects: Array[Effect] = []


## A one-line description of what using this ability does — each effect's action described and joined, for a
## button tooltip. Empty when no effect describes itself.
func describe() -> String:
	var parts: Array[String] = []
	for effect in effects:
		if effect != null and effect.action != null:
			var line := effect.action.describe()
			if not line.is_empty():
				parts.append(line)
	return ", ".join(parts)
