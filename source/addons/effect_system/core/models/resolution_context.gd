class_name ResolutionContext
extends RefCounted
## The live state an [Effect] resolves against: who is acting, which entities are on each side, and the
## services resolution needs (a seeded RNG and a chooser). One context flows through target selection, amount
## evaluation, condition checks, and the modification pipeline, so every step reads from the same place.

## The entity that owns the effect being resolved (the source of a change, the stat [StatAmount] reads, ...).
var source: Entity
## [member source]'s own side, including [member source]. Used by self/ally relations.
var allies: Array[Entity] = []
## The opposing side. Used by opponent relations.
var opponents: Array[Entity] = []
## The entity that raised the current hook (e.g. whoever caused the change being reacted to), if any.
var instigator: Entity
## Seeded source of randomness. Threaded in by the host so resolution is deterministic and replayable —
## resolution must never call the global [method @GlobalScope.randf].
var rng: RandomNumberGenerator
## Resolves player/agent choices ("choose an opponent"). The single seam runtime selection funnels through.
var chooser: EffectChooser


## Builds a context. The host supplies the sides; [param rng_seed] is set on a fresh generator so the same
## seed always produces the same random selections, and [param chooser] defaults to [AutoChooser].
static func create(
	p_source: Entity,
	p_allies: Array[Entity],
	p_opponents: Array[Entity],
	rng_seed: int = 0,
	p_chooser: EffectChooser = null,
) -> ResolutionContext:
	var context := ResolutionContext.new()
	context.source = p_source
	context.allies = p_allies
	context.opponents = p_opponents
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = rng_seed
	context.chooser = p_chooser if p_chooser != null else AutoChooser.new()
	return context
