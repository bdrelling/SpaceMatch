class_name Status
extends Resource
## The definition of a status effect (poison, bleed, shield, ...), authored as a resource. A [StatusStack]
## pairs one of these with a live count on an [Entity].

## Whether the status helps or harms its holder.
enum Sign {
	POSITIVE,
	NEGATIVE,
}

## Identifier used by [ApplyStatusAction] / [RemoveStatusAction] / [HasStatusCondition] to refer to this status.
@export var name: StringName
## Whether this status is a buff or a debuff.
@export var sign: Sign = Sign.NEGATIVE
## Maximum stack count; 0 or below means uncapped.
@export var cap: int = 0
## How a fresh application combines with the stacks already present.
@export var stack_rule: StackRule
## How stacks fall off over time or on events.
@export var decay_rule: DecayRule
## Effects this status fires when its triggers match.
@export var effects: Array[TriggeredEffect] = []
## Stat modifiers this status applies while active.
@export var modifiers: Array[Modifier] = []
## Transforms this status applies to changes passing through its holder — absorb, mitigate, amplify, clamp. On
## the target of a change these read as defenses (Block, armor, Vulnerable); on the source they read as
## offense (Weak, empower). See [ModificationPipeline].
@export var transforms: Array[ModificationStep] = []
