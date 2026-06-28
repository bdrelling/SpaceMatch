class_name EffectChooser
extends RefCounted
## The seam runtime target selection funnels through. When an effect must pick among candidates at
## resolution time ("choose an enemy"), it calls [method choose] instead of deciding for itself. A game
## supplies its own subclass — a UI prompt that [code]await[/code]s a tap, an AI heuristic, a network
## relay — so the engine stays agnostic about who is choosing or whether the choice blocks.

## Returns one entity from [param candidates] (or [code]null[/code] when empty). [param source] is the
## entity asking, for prompts that frame the choice. May be a coroutine: a UI chooser awaits the player.
func choose(candidates: Array[Entity], _source: Entity) -> Entity:
	return candidates[0] if not candidates.is_empty() else null
