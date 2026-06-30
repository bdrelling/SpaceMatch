# Effect System

Generic entity status/effect engine: entities with stats and stacking statuses, triggered effects with pluggable triggers, hooks, targets, amounts, actions, and conditions. No game-specific content.

```
# ── Layers ────────────────────────────────────────
# core/    every game — the neutral engine: stats, statuses, effects, triggers, hooks,
#          relational targeting, and the modification pipeline with its steps.
# combat/  opt-in — the combat hooks (and combat-specific authored content) that ride the core
#          seam. Tagged "combat" below.
# spatial/ opt-in, rare — positional targeting. Tagged "spatial" below.
#
# The abstract bases (StatBlock, StackRule, DecayRule, Trigger, Hook, Target, Amount, Action,
# Condition, ModificationStep) plus the structural types (Entity, Status, StatusStack, Modifier,
# TriggeredEffect, Ability, Effect, Modification, ResolutionContext) ARE the system. Every concrete
# subtype below them — ModifyStatAction, ApplyStatusAction, PhaseTrigger, SelfTarget, MultiplierStep, ... — ships
# as an EXAMPLE: reusable, but removable. A game keeps the ones it wants and adds its own.

# Entity — a combatant the engine acts on. The engine reaches stats ONLY through the StatBlock contract
# (get_stat/set_stat/stat_names); it never computes the base→effective→current layering — the GAME owns that.
# base_stats is the baseline the game supplies (its effective profile: intrinsic stats + loadout). current_stats
# is the live layer: seeded from the baseline, depleting pools (health, shields) fall below it via ModifyStatAction,
# and the runtime folds active-status modifiers into it (see Runtime → stat contribution). The game decides what
# is a depleting pool vs a derived stat; the engine only reads and writes by name.
Entity {
  id:             int
  base_stats:     StatBlock     # the baseline / effective profile the game supplies (intrinsic + loadout)
  current_stats:  StatBlock     # the live layer: pools deplete here, status modifiers fold in
  statuses:       Array[StatusStack]
  resources:      Array[ResourcePool]    # spendable AbilityResource amounts the entity holds (its "mana")
}

# StatBlock — abstract stats contract. Games subclass it with typed @export fields, so name access
# bridges to Godot get()/set(): no Dictionary and no sync layer. In-game you use typed access and only
# authored data ever names a stat as a StringName.
StatBlock {
  get_stat(name)  -> Variant            # hard error if name is absent
  set_stat(name, value)
  stat_names()    -> Array[StringName]
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

  stat:        StringName
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
  maximum:  int                      # most an entity can hold; 0 = unlimited
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
# scalar field on the trigger's hook equals the raised hook's. Entity-typed fields (attacker, ...) are payload,
# ignored for matching — so a bare DamageReceivedHook matches any hit; one with damage_type set matches only it.
Hook { }
OnApplyHook        extends Hook { }                        # core — a status was applied
WhenHitHook        extends Hook { }                        # combat
OnAttackHook       extends Hook { }                        # combat
DamageReceivedHook extends Hook { amount: int,  damage_type: StringName,  attacker: Entity }   # combat


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
ConstantAmount extends Amount { value: int }
StatAmount     extends Amount { stat: StringName }   # reads the source entity's stat


# ── Action ────────────────────────────────────────
Action {
  resolve(ctx, target)    # carries out the action against one resolved target
}
# ModifyStatAction — the single value-changing action. Damage, healing, and resource gain are all this, with
# a different tag and direction. The magnitude runs through the ModificationPipeline first.
ModifyStatAction   extends Action {
  stat:          StringName
  amount:        Amount
  tag:           StringName    # "damage", "heal", ... — names the change for steps and hooks
  subtracts:     bool          # true = remove (damage, paying a cost);  false = add (heal, gain)
  minimum:       int           # floor the stat lands on (default 0)
  maximum_stat:  StringName     # optional ceiling read from another stat (e.g. max_health); empty = none
}
ApplyStatusAction  extends Action { status: StringName,  count: int }
RemoveStatusAction extends Action { status: StringName }


# ── Condition (gates an Effect on game state) ─────
Condition {
  holds(ctx) -> bool    # whether condition is satisfied in context
}
HasStatusCondition     extends Condition { target: Target,  status: StringName }
StatThresholdCondition extends Condition {
  enum Comparison { LESS, EQUAL, GREATER }

  target:      Target
  stat:        StringName
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
  stat:    StringName     # the named value being changed
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
FlatMitigationStep extends ModificationStep { stat: StringName }              # subtracts a stat, e.g. armor; order 200
AbsorbStep         extends ModificationStep { stat: StringName }              # drains a pool, e.g. Block; order 300
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

# Stat contribution — folds the entity's active-status modifiers (scaled by stack count) onto a StatBlock the
# GAME supplies from its own stat computation. The engine's only hand in stats; it stores no derived block.
apply_modifiers(entity, into: StatBlock)

# Resources — an entity holds ResourcePools; an ability's ResourceCosts are checked and paid here. The game refills
# pools as it collects (grant), clamped to each AbilityResource's maximum.
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
