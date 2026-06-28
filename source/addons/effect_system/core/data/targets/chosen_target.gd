class_name ChosenTarget
extends Target
## One opposing entity picked through the context's [EffectChooser] — the example that routes target selection
## through the choice seam. With an [AutoChooser] it resolves synchronously; with a UI chooser it
## [code]await[/code]s the player, which is why [method Target.resolve] is awaited by callers.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if context.opponents.is_empty():
		return result
	var picked: Entity = await context.chooser.choose(context.opponents, context.source)
	if picked != null:
		result.append(picked)
	return result
