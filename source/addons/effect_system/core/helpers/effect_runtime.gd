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


## Removes the status named [param status_name] from [param entity], then raises [OnRemoveHook] (carrying the
## name) so reactions fire — only when a stack was actually present. [param allies] / [param opponents] supply the
## sides for that hook; they default empty for callers that just need the removal.
func remove_status(entity: Entity, status_name: StringName, allies: Array[Entity] = [], opponents: Array[Entity] = []) -> void:
	var existed := StatusEngine.find_stack(entity, status_name) != null
	StatusEngine.remove_status(entity, status_name)
	if existed:
		var hook := OnRemoveHook.new()
		hook.status = status_name
		await raise_hook(entity, allies, opponents, hook, entity)


## Fires [PhaseTrigger]s and ticks [TimingDecayRule]s for [param entity] at [param phase], raising [OnExpireHook]
## for any status that fell off.
func tick_phase(entity: Entity, allies: Array[Entity], opponents: Array[Entity], phase: StringName) -> void:
	var context := _context(entity, allies, opponents)
	await TriggerEngine.fire_phase(entity, phase, context)
	await _raise_expiries(entity, allies, opponents, DecayEngine.tick_phase(entity, phase))


## The hook bus: raises [param hook] on [param entity] — firing [HookTrigger]s and ticking [TriggerDecayRule]s —
## with [param instigator] recorded as who raised it. Statuses the tick expires raise their own [OnExpireHook].
func raise_hook(entity: Entity, allies: Array[Entity], opponents: Array[Entity], hook: Hook, instigator: Entity = null) -> void:
	var context := _context(entity, allies, opponents, instigator)
	await TriggerEngine.fire_hook(entity, hook, context)
	await _raise_expiries(entity, allies, opponents, DecayEngine.tick_hook(entity, hook))


## Pays [param ability]'s costs from [param source] and runs its effects. Returns false (running nothing) when the
## source cannot afford it.
func use_ability(source: Entity, allies: Array[Entity], opponents: Array[Entity], ability: Ability) -> bool:
	var context := _context(source, allies, opponents)
	return await AbilityRunner.run(ability, context)


## Folds [param entity]'s active-status modifiers onto [param into] (the game's own stat block).
func apply_modifiers(entity: Entity, into: EntityStats) -> void:
	StatusModifiers.apply(entity, into)


## Raises an [OnExpireHook] (carrying its name) for each status in [param expired] — the statuses a decay tick
## just dropped to zero — so reactions can observe them falling off.
func _raise_expiries(entity: Entity, allies: Array[Entity], opponents: Array[Entity], expired: Array[Status]) -> void:
	for status in expired:
		if status == null:
			continue
		var hook := OnExpireHook.new()
		hook.status = status.name
		await raise_hook(entity, allies, opponents, hook, entity)


## Builds a [ResolutionContext] for [param source] carrying this runtime's seed, chooser, and status catalog.
func _context(source: Entity, allies: Array[Entity], opponents: Array[Entity], instigator: Entity = null) -> ResolutionContext:
	var context := ResolutionContext.create(source, allies, opponents, rng_seed, chooser)
	context.instigator = instigator
	context.status_catalog = status_catalog
	return context
