class_name ResolutionContext
extends RefCounted
## The live state an [Effect] resolves against: who is acting, which entities are on each side, and the
## services resolution needs (a seeded RNG and a chooser). One context flows through target selection,
## amount evaluation, condition checks, and the damage pipeline, so every step reads from the same place.

## The entity that owns the effect being resolved (the source of damage, the stat [StatAmount] reads, ...).
var source: Entity
## [member source]'s own side, including [member source]. Used by self/ally relations.
var allies: Array[Entity] = []
## The opposing side. Used by enemy relations.
var enemies: Array[Entity] = []
## The entity that raised the current hook (whoever dealt the damage being reacted to), if any.
var attacker: Entity
## Seeded source of randomness. Threaded in by the host so resolution is deterministic and replayable —
## resolution must never call the global [method @GlobalScope.randf].
var rng: RandomNumberGenerator
## Resolves player/agent choices ("choose an enemy"). The single seam runtime selection funnels through.
var chooser: EffectChooser

## Name of the stat damage drains and healing restores (the entity's vitality pool). Game-configurable so
## the engine never hardcodes a stat name; defaults to the conventional [code]health[/code].
var health_stat: StringName = &"health"


## Builds a context. The host supplies the sides; [param rng_seed] is set on a fresh generator so the same
## seed always produces the same random selections, and [param chooser] defaults to [AutoChooser].
static func create(
	p_source: Entity,
	p_allies: Array[Entity],
	p_enemies: Array[Entity],
	rng_seed: int = 0,
	p_chooser: EffectChooser = null,
) -> ResolutionContext:
	var context := ResolutionContext.new()
	context.source = p_source
	context.allies = p_allies
	context.enemies = p_enemies
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = rng_seed
	context.chooser = p_chooser if p_chooser != null else AutoChooser.new()
	return context
