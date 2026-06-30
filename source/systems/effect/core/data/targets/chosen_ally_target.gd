class_name ChosenAllyTarget
extends Target
## One entity from the source's own side picked through the context's [EffectChooser]. The ally-side mirror of
## [ChosenTarget]: with an [AutoChooser] it resolves synchronously; with a UI chooser it [code]await[/code]s the
## player, which is why [method Target.resolve] is awaited by callers.

func resolve(context: ResolutionContext) -> Array[Entity]:
	var result: Array[Entity] = []
	if context.allies.is_empty():
		return result
	var picked: Entity = await context.chooser.choose(context.allies, context.source)
	if picked != null:
		result.append(picked)
	return result
