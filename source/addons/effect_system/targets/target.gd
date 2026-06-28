class_name Target
extends Resource
## Selects which entity / entities an [Effect]'s [Action] resolves against. The subclasses below are
## defaults; games can add their own [Target] subclasses for relations specific to their layout.

## The entities this target selects in [param context]. The base selects nothing. A subclass that needs a
## runtime decision (random pick, player choice) reads [member ResolutionContext.rng] /
## [member ResolutionContext.chooser]; such a subclass may be a coroutine, so callers [code]await[/code]
## the result.
func resolve(_context: ResolutionContext) -> Array[Entity]:
	return []
