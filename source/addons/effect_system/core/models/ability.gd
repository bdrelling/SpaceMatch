class_name Ability
extends Resource
## A player-facing ability: a named, costed bundle of [Effect]s run in order.

@export var name: StringName
@export var cost: int = 0
@export var effects: Array[Effect] = []
