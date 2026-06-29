class_name Ability
extends Resource
## A player-facing ability: a named bundle of [Effect]s run in order, paid for with [ResourceCost]s.

@export var name: StringName
## What using this ability spends; empty is free. Paid by [AbilityRunner] against the source's [ResourcePool]s.
@export var costs: Array[ResourceCost] = []
@export var effects: Array[Effect] = []
