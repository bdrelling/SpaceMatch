# Effect System

Generic entity status/effect engine: entities with stats and stacking statuses, triggered effects with pluggable triggers, hooks, targets, amounts, actions, and conditions. No game-specific content.

```
# ── Layers ────────────────────────────────────────
# core/    every game — the neutral engine: stats, statuses, effects, triggers, hooks (including the generic
#          action / stat-change events), relational targeting, and the modification pipeline with its steps.
# spatial/ opt-in, rare — positional targeting. Tagged "spatial" below.
#
# The abstract bases (EntityStats, StackRule, DecayRule, Trigger, Hook, Target, Amount, Action,
# Condition, ModificationStep) plus the structural types (Entity, EntityStat, Status, StatusStack, Modifier,
# TriggeredEffect, Ability, Effect, Modification, ResolutionContext) ARE the system. Every concrete
# subtype below them — ModifyStatAction, ApplyStatusAction, PhaseTrigger, SelfTarget, MultiplierStep, ... — ships
# as an EXAMPLE: reusable, but removable. A game keeps the ones it wants and adds its own.

# Entity — a combatant the engine acts on. The engine reaches stats ONLY through the EntityStats contract
# (get_stat/set_stat/stat_names); it never computes the base→effective→current layering — the GAME owns that.
# base_stats is the baseline the game supplies (its effective profile: intrinsic stats + loadout). current_stats
# is the live layer: seeded from the baseline, depleting pools (health, shields) fall below it via ModifyStatAction,
# and the runtime folds active-status modifiers into it (see Runtime → stat contribution). The game decides what
# is a depleting pool vs a derived stat; the engine only reads and writes by key.
Entity {
  id:             int
  base_stats:     EntityStats   # the baseline / effective profile the game supplies (intrinsic + loadout)
  current_stats:  EntityStats   # the live layer: pools deplete here, status modifiers fold in
  statuses:       Array[StatusStack]
  resources:      Array[ResourcePool]    # spendable AbilityResource amounts the entity holds (its "mana")
}

# EntityStats — the stat collection: a StatPool keyed by an EntityStat (its name). The dict is the storage AND
# the math, so a block holds whatever stats it is given with no typed subclass required. Games may layer
# typed-field sugar over it (the game's StarshipStats does), but the dictionary is the source of truth.
EntityStats {
  values:         Dictionary[StringName, StatPool]   # a current/min/max pool per stat key
  get_stat(stat: EntityStat)  -> int            # the pool's current; zero when the block holds no such stat
  set_stat(stat: EntityStat, value)             # writes current, clamped to the pool's minimum..maximum
  get_maximum/set_maximum(stat[, value])        # the pool's ceiling (0 = unlimited)
  get_minimum/set_minimum(stat[, value])        # the pool's floor
  pool_for(stat: EntityStat)  -> StatPool
  add(other: EntityStats)                        # sums another block in (current, minimum, maximum) key by key
  stat_names()    -> Array[StringName]
}

# EntityStat — a stat definition: its key (name). The neutral counterpart of AbilityResource — authored data and
# code reference a stat as an EntityStat instead of a raw StringName, so stat references are type-checked.
EntityStat {
  name:           StringName
}

# Status — the definition (poison, bleed, shield, ...), authored as a resource
Status {
  enum Sign { POSITIVE, NEGATIVE }

  name:        StringName
  sign:        Sign
  cap:         int
  stack_rule:  StackRule
  decay_rule:  DecayRule
  effects:     Array[TriggeredEffect]
  modifiers:   Array[Modifier]
  transforms:  Array[ModificationStep]   # reshape changes passing through the holder (absorb, mitigate, amplify, clamp)
}

# StatusStack — a Status applied to an entity, with its live count
StatusStack {
  status:  Status
  count:   int
}

TriggeredEffect {
  trigger:  Trigger
  effects:  Array[Effect]
}

Effect {
  target:      Target
  action:      Action
  conditions:  Array[Condition]
  resolve(ctx)                  # coroutine; gates on conditions, resolves targets (await-safe), runs action per target
}

Modifier {
  enum Operation { ADD, MULTIPLY }   # ADD: flat delta;  MULTIPLY: scales the stat

  stat:        EntityStat
  operation:   Operation
  amount:      float                 # applied once per stack: a status at N stacks contributes the modifier N times
}

Ability {
  name:     StringName
  costs:    Array[ResourceCost]      # what using it spends; empty = free. Checked and paid by the runtime (run_ability).
  effects:  Array[Effect]
}

# AbilityResource — a spendable pool an ability costs: the neutral "mana" base (energy, ammo, a tile economy).
# Games extend or author this for their own resource kinds; an entity holds how much of each it has (a ResourcePool)
# and abilities spend amounts of them (a ResourceCost). Distinct from a stat — a stat is a characteristic (and may
# govern how fast a resource is collected), a resource is a pool you spend.
AbilityResource {
  name:     StringName
}

# ResourceCost — an amount of one AbilityResource that using an Ability spends. A cost and a pool match by the
# resource's name.
ResourceCost {
  resource:  AbilityResource
  amount:    int
}

# ResourcePool — how much of one AbilityResource an entity currently holds (the resource is the kind, this is the
# amount on hand). Lives on the Entity; spent to pay ResourceCosts, refilled as the game collects.
ResourcePool {
  resource:  AbilityResource
  amount:    int
  maximum:   int                     # most this pool may hold; 0 = unlimited (the pool owns its cap, not the resource)
}

# StatPool — the live value of one stat plus its bounds (the EntityStats counterpart of ResourcePool). One stat
# key owns its current amount and the floor/ceiling it is held within, so a stat's value and cap never split.
StatPool {
  current:   int
  minimum:   int                     # least this stat may hold (usually 0)
  maximum:   int                     # most this stat may hold; 0 = unlimited (mirrors ResourcePool)
  set_current(value)                 # clamps to minimum..maximum
  missing()  -> int                  # maximum − current, floored at 0; 0 when unbounded
}


# ── Phase (shared turn-lifecycle tag) ─────────────
Phase { TURN_START, TURN_END, ROUND_END }


# ── StackRule ─────────────────────────────────────
StackRule { }
StackStackRule       extends StackRule { }
KeepHighestStackRule extends StackRule { }


# ── DecayRule ─────────────────────────────────────
DecayRule { }
TimingDecayRule    extends DecayRule { phase: Phase,  quantity: int }
TriggerDecayRule   extends DecayRule { hook: Hook,    quantity: int }
ThresholdDecayRule extends DecayRule { value: int,    quantity: int }


# ── Trigger ───────────────────────────────────────
Trigger { }
PhaseTrigger extends Trigger { phase: Phase }
HookTrigger  extends Trigger { hook: Hook }
CountTrigger extends Trigger { value: int }


# ── Hook (pluggable; defaults below) ──────────────
# A raised Hook matches a HookTrigger / TriggerDecayRule's hook when they share a class AND every non-default
# scalar field on the trigger's hook equals the raised hook's — so a bare hook matches any of its class, one
# with `tag` set matches only that tag. Hooks are bare event tokens; who / whom / how-much come from the context.
Hook { }
OnApplyHook        extends Hook { }                  # a status was applied
StatModifiedHook   extends Hook { tag: StringName }  # a stat changed, raised on the subject (reflect, undead, ...)
OutgoingActionHook extends Hook { tag: StringName }  # a change you caused, raised on the actor (lifesteal, ...)
IncomingActionHook extends Hook { tag: StringName }  # an action targeted you, raised on the subject (any magnitude)


# ── Target ────────────────────────────────────────
Target {
  resolve(ctx) -> Array[Entity]    # selects entities in context
}
SelfTarget           extends Target { }
OpponentTarget       extends Target { }              # the first opposing entity
AllOpponentsTarget   extends Target { }
InstigatorTarget     extends Target { }              # whoever raised the current hook
RandomOpponentTarget extends Target { }              # picks one foe at random (seeded, deterministic)
ChosenTarget         extends Target { }              # awaits through ctx.chooser; interactive
SidesTarget          extends Target { radius: int }  # spatial — neighbours in the allies lineup


# ── Amount (pluggable; how a value is computed) ────
Amount {
  evaluate(ctx) -> int    # computes the numeric value in context
}
ConstantAmount     extends Amount { value: int }
CurrentStatAmount  extends Amount { stat: EntityStat }   # reads the stat pool's current value on the source
MaximumStatAmount  extends Amount { stat: EntityStat }   # reads the stat pool's ceiling on the source
MissingStatAmount  extends Amount { stat: EntityStat }   # maximum − current of the stat's pool on the source
ModificationAmount extends Amount { }                    # the magnitude of the change being reacted to (ctx.modification.amount)


# ── Action ────────────────────────────────────────
Action {
  resolve(ctx, target)    # carries out the action against one resolved target
}
# ModifyStatAction — the single value-changing action. Damage, healing, and resource gain are all this, with
# a different tag and direction. The magnitude runs through the ModificationPipeline first.
ModifyStatAction   extends Action {
  stat:          EntityStat
  amount:        Amount
  tag:           StringName    # "damage", "heal", ... — names the change for steps and hooks
  subtracts:     bool          # true = remove (damage, paying a cost);  false = add (heal, gain)
  minimum:       int           # extra floor on top of the stat pool's own minimum (default 0)
}
# The ceiling comes from the target stat's StatPool.maximum — set_stat clamps to it, so healing cannot overfill.
ApplyStatusAction   extends Action { status: StringName,  count: int }
RemoveStatusAction  extends Action { status: StringName }
DrainResourceAction extends Action { resources: Array[AbilityResource], amount: Amount }  # subtracts amount from each pool on the target


# ── Condition (gates an Effect on game state) ─────
Condition {
  holds(ctx) -> bool    # whether condition is satisfied in context
}
HasStatusCondition     extends Condition { target: Target,  status: StringName }
StatThresholdCondition extends Condition {
  enum Comparison { LESS, EQUAL, GREATER }

  target:      Target
  stat:        EntityStat
  comparison:  Comparison
  value:       int
}


# ── Resolution ────────────────────────────────────
# Effects resolve against a shared ResolutionContext carrying state, seeded RNG, and a chooser. All
# decisions route through the same seam so resolution is deterministic (same seed = same outcome) and
# player choice can hook in without rewriting.

ResolutionContext {
  source:      Entity                                       # entity carrying the effect
  allies:      Array[Entity]                                # source's side
  opponents:   Array[Entity]                                # opposing side
  instigator:  Entity                                       # who raised the current hook, if any
  rng:         RandomNumberGenerator                        # seeded
  chooser:     EffectChooser                                # handles target/decision selection
  status_catalog:  Dictionary                               # StringName -> Status; how ApplyStatusAction/RemoveStatusAction resolve a name to its resource
  modification:    Modification                             # the change in flight a reaction is responding to (set by ModifyStatAction); ModificationAmount reads it
}

EffectChooser {
  choose(candidates: Array[Entity], source: Entity) -> Entity    # async; picks one candidate
}
AutoChooser extends EffectChooser { }    # default; synchronously picks the first candidate


# ── Modification pipeline ──────────────────────────
# ModifyStatAction builds a mutable Modification and runs it through a fixed-order pipeline. Each Status can
# carry ModificationSteps that reshape the change (amplify, mitigate, absorb, clamp). Order is enforced
# by order() (lowest first): amplify (Vulnerable), mitigate (armor), absorb (Block), clamp (Intangible),
# floor to zero. Steps act on any tag/stat — damage, healing, energy — so the engine has no special
# "damage" path; a step scopes itself by tag.

Modification {
  source:  Entity
  target:  Entity
  stat:    EntityStat     # the named value being changed
  amount:  int            # mutable magnitude; steps reshape in place, the pipeline floors it at zero
  tag:     StringName     # "damage", "heal", ... ; steps filter on it
}

ModificationPipeline {
  resolve(modification, ctx) -> int    # runs every applicable step in order, returns the final magnitude
}

ModificationStep {
  tag:               StringName            # only acts on matching modifications; empty = any
  order()         -> int                   # sort key; lower runs first
  applies_to(mod) -> bool
  modify(mod, ctx)                         # mutates modification.amount
}
MultiplierStep     extends ModificationStep { factor: float }                 # scales (Vulnerable / Weak); order 100
FlatMitigationStep extends ModificationStep { stat: EntityStat }              # subtracts a stat, e.g. armor; order 200
AbsorbStep         extends ModificationStep { stat: EntityStat }              # drains a pool, e.g. Block; order 300
ClampStep          extends ModificationStep { minimum: int, maximum: int }    # bounds the change, e.g. Intangible; order 400


# ── Runtime ────────────────────────────────────────
# The data above is inert until the runtime drives it. The runtime is the neutral engine loop: it applies and
# decays statuses, fires triggers, dispatches hooks, folds status modifiers into stats, and runs abilities. The
# HOST (the game's turn loop) decides WHEN — it raises phases and hooks and asks for stats; the runtime does the
# rest. Entry points build/carry a ResolutionContext so resolution stays deterministic (seeded RNG, one chooser).

# Status lifecycle — apply honours the StackRule (sum vs keep-highest) and the cap; decay reduces a stack and
# removes it at zero. The ApplyStatusAction / RemoveStatusAction actions delegate here (resolving the name via status_catalog).
apply_status(entity, status, count, ctx) -> StatusStack
remove_status(entity, status_name)

# Decay — the host calls these at the moments it owns; each ticks the matching DecayRule on the entity's statuses.
tick_phase(entity, phase)        # TimingDecayRule whose phase matches
tick_hook(entity, hook)          # TriggerDecayRule whose hook matches (see Hook)
tick_thresholds(entity)          # ThresholdDecayRule whose count has reached value

# Triggers — run the matching TriggeredEffect.effects (through Effect.resolve).
fire_phase(entity, phase, ctx)   # PhaseTrigger
fire_hook(entity, hook, ctx)     # HookTrigger (see Hook)
fire_counts(entity, ctx)         # CountTrigger whose count has reached value

# Hook dispatch (the bus) — raising a hook fans it to both HookTriggers (fire) and TriggerDecayRules (tick) for
# the entity, with ctx.instigator set to whoever raised it.
raise_hook(entity, hook, instigator, ctx)

# Stat contribution — folds the entity's active-status modifiers (scaled by stack count) onto an EntityStats the
# GAME supplies from its own stat computation. The engine's only hand in stats; it stores no derived block.
apply_modifiers(entity, into: EntityStats)

# Resources — an entity holds ResourcePools; an ability's ResourceCosts are checked and paid here. The game refills
# pools as it collects (grant), clamped to each ResourcePool's maximum.
can_afford(entity, costs) -> bool
spend(entity, costs)
grant(entity, resource, amount)

# Ability — pays the ability's ResourceCosts then runs its effects in order; returns false and runs nothing when
# the entity can't afford it.
run_ability(ability, ctx) -> bool

# Host entry — the one object the game holds. It carries the seed, chooser, and status_catalog, builds a
# ResolutionContext per call, and delegates to the above so the host never wires resolution by hand.
EffectRuntime {
  apply_status / remove_status / tick_phase / raise_hook / run_ability / apply_modifiers
}
```
