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
## Maps a status name to its [Status] resource, so [ApplyStatusAction] / [RemoveStatusAction] (which name a
## status by [StringName]) can resolve it. Empty by default; the host / [EffectRuntime] supplies it.
var status_catalog: Dictionary = {}
## The change currently in flight — the [Modification] a reaction is responding to. A [ModifyStatAction] sets
## it as it resolves, so an effect fired off that change can read what just happened (its magnitude via
## [ModificationAmount]); who caused it and who it landed on come from [member instigator] and [member source].
## Null when no change is in flight.
var modification: Modification


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


## Builds the context a reaction resolves in: [param reactor] becomes the source (so [SelfTarget] hits it and
## its own statuses are the ones firing), [param cause] is who caused the change being reacted to (so
## [InstigatorTarget] hits them), and the in-flight [param in_flight] change is carried so the reaction can read
## what just happened. Sides are taken relative to the reactor; the seeded RNG, chooser, and status catalog are
## shared with this context.
func reaction(reactor: Entity, cause: Entity, in_flight: Modification) -> ResolutionContext:
	var next := ResolutionContext.new()
	next.source = reactor
	next.instigator = cause
	if reactor in opponents:
		next.allies = opponents
		next.opponents = allies
	else:
		next.allies = allies
		next.opponents = opponents
	next.rng = rng
	next.chooser = chooser
	next.status_catalog = status_catalog
	next.modification = in_flight
	return next
