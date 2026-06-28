class_name DamagePacket
extends RefCounted
## A damage instance in flight. [DealDamageAction] builds one and the [DamagePipeline] hands it to each
## [DamageStep], which mutates [member amount] in place (and may drain a stat, e.g. a shield pool). Damage
## is an object the pipeline transforms, never a bare number applied at the source — that is what lets
## amplify, mitigate, absorb, and clamp compose instead of being hardcoded into every action.

## Who is dealing the damage. Outgoing steps come from this entity's statuses.
var source: Entity
## Who is taking the damage. Incoming steps come from this entity's statuses, and the final amount is
## subtracted from its vitality stat.
var target: Entity
## The current damage value. Steps read and rewrite this; the pipeline floors it at zero before it lands.
var amount: int
## What kind of damage this is (kinetic, thermal, ...). Steps may key resistances off it.
var damage_type: StringName
