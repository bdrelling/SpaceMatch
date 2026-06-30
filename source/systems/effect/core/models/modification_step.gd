class_name ModificationStep
extends Resource
## One transform a status applies to a [Modification] passing through it (Block absorb, Vulnerable amplify,
## armor mitigation, Intangible clamp). Steps are authored on a [Status]; the engine never hardcodes a stat
## name like "armor" — a step that mitigates names the stat it reads. The subclasses are defaults; games keep
## the ones they want and add their own, exactly like [Action] and [Target].
##
## [method order] fixes WHEN a step runs, independent of authoring order: the [ModificationPipeline] runs
## every step at a lower order before any at a higher one, so a Vulnerable multiplier always applies before
## armor subtraction no matter how the data was authored.

## Only acts on modifications whose [member Modification.tag] matches this. Empty matches any tag.
@export var tag: StringName = &""


## The sort key fixing when this step runs (lower runs first). Subclasses override.
func order() -> int:
	return 0


## Whether this step acts on [param modification], matched by [member tag].
func applies_to(modification: Modification) -> bool:
	return tag == &"" or tag == modification.tag


## Mutates [param modification] in place. The base does nothing.
func modify(_modification: Modification, _context: ResolutionContext) -> void:
	pass
