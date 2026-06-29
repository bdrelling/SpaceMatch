class_name EffectRuntime
extends RefCounted
## The one object the host (the game's turn loop) holds to drive the effect engine. It carries the seed, the
## chooser, and the status catalog, builds a [ResolutionContext] per call, and delegates to the static engine
## helpers — so the host raises phases/hooks and asks for stats without wiring resolution by hand. The host
## decides WHEN; the runtime does the rest.

## Seed for each per-call [ResolutionContext]'s RNG, so selection stays deterministic.
var rng_seed: int = 0
## Chooser for interactive selection; [ResolutionContext.create] falls back to [AutoChooser] when null.
var chooser: EffectChooser
## Maps a status name to its [Status] resource, for [ApplyStatusAction] / [RemoveStatusAction].
var status_catalog: Dictionary = {}


## Applies [param count] stacks of [param status] to [param entity], then raises [OnApplyHook] so reactions fire.
func apply_status(entity: Entity, allies: Array[Entity], opponents: Array[Entity], status: Status, count: int = 1) -> StatusStack:
	var context := _context(entity, allies, opponents)
	var stack := StatusEngine.apply_status(entity, status, count, context)
	await raise_hook(entity, allies, opponents, OnApplyHook.new(), entity)
	return stack


## Removes the status named [param status_name] from [param entity].
func remove_status(entity: Entity, status_name: StringName) -> void:
	StatusEngine.remove_status(entity, status_name)


## Fires [PhaseTrigger]s and ticks [TimingDecayRule]s for [param entity] at [param phase].
func tick_phase(entity: Entity, allies: Array[Entity], opponents: Array[Entity], phase: StringName) -> void:
	var context := _context(entity, allies, opponents)
	await TriggerEngine.fire_phase(entity, phase, context)
	DecayEngine.tick_phase(entity, phase)


## The hook bus: raises [param hook] on [param entity] — firing [HookTrigger]s and ticking [TriggerDecayRule]s —
## with [param instigator] recorded as who raised it.
func raise_hook(entity: Entity, allies: Array[Entity], opponents: Array[Entity], hook: Hook, instigator: Entity = null) -> void:
	var context := _context(entity, allies, opponents, instigator)
	await TriggerEngine.fire_hook(entity, hook, context)
	DecayEngine.tick_hook(entity, hook)


## Runs [param ability]'s effects with [param source] acting. Cost stays with the host.
func use_ability(source: Entity, allies: Array[Entity], opponents: Array[Entity], ability: Ability) -> void:
	var context := _context(source, allies, opponents)
	await AbilityRunner.run(ability, context)


## Folds [param entity]'s active-status modifiers onto [param into] (the game's own stat block).
func apply_modifiers(entity: Entity, into: StatBlock) -> void:
	StatusModifiers.apply(entity, into)


## Builds a [ResolutionContext] for [param source] carrying this runtime's seed, chooser, and status catalog.
func _context(source: Entity, allies: Array[Entity], opponents: Array[Entity], instigator: Entity = null) -> ResolutionContext:
	var context := ResolutionContext.create(source, allies, opponents, rng_seed, chooser)
	context.instigator = instigator
	context.status_catalog = status_catalog
	return context
