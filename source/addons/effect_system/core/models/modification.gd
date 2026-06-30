class_name Modification
extends RefCounted
## A change in flight to one named stat. A [ModifyStatAction] builds one and the [ModificationPipeline] hands
## it to each [ModificationStep] a status contributes, which mutates [member amount] in place (and may drain a
## stat, e.g. a shield pool). The change is an object the pipeline transforms — never a bare number applied at
## the source — so amplify, mitigate, absorb, and clamp compose instead of being hardcoded. Damage, healing,
## and resource gain are all the same object: only [member tag] and the action's direction differ.

## Who is causing the change. Outgoing steps come from this entity's statuses.
var source: Entity
## Who the change lands on. Incoming steps come from this entity's statuses, and the final amount is written
## to its [member stat].
var target: Entity
## The stat being changed (health, a shield pool, a resource, ...).
var stat: EntityStat
## The current magnitude of the change. Steps read and rewrite this; the pipeline floors it at zero.
var amount: int
## What kind of change this is ("damage", "heal", ...). Steps and hooks key off it to scope themselves.
var tag: StringName
## How deep in a reaction cascade this change is: 0 for a change made directly, +1 for each change a reaction
## spawned off another. Reactions read it (e.g. "react only at depth 0") and the engine caps it so reflections
## of reflections terminate.
var depth: int = 0
