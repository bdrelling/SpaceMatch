class_name Entity
extends Resource
## A combatant the effect engine acts on: persistent stats plus the live statuses applied to it. Games
## subclass [StatBlock] for [member base_stats] / [member current_stats]; the engine reads and mutates
## stats by name, so it never needs to know a game's concrete stat set.

## Stable identifier for this entity within an encounter.
@export var id: int = 0
## The entity's unmodified stats (a game-defined [StatBlock] subclass).
@export var base_stats: StatBlock
## Stats after active statuses' modifiers are applied; derived from [member base_stats].
@export var current_stats: StatBlock
## Status effects currently on this entity, each with its live stack count.
@export var statuses: Array[StatusStack] = []
## Spendable resources this entity holds — its [AbilityResource] pools (the "mana" an [Ability] costs).
@export var resources: Array[ResourcePool] = []
