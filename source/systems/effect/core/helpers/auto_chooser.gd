class_name AutoChooser
extends EffectChooser
## Default chooser: takes the first candidate, synchronously and deterministically. Stands in for a human
## chooser in tests, headless resolution, and any context with no interactive picker wired up.

func choose(candidates: Array[Entity], _source: Entity) -> Entity:
	return candidates[0] if not candidates.is_empty() else null
