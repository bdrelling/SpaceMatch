class_name Effect
extends Resource
## One atomic thing that happens: an [Action] resolved against a [Target], gated by [member conditions].
## The action only runs when every condition holds.

@export var target: Target
@export var action: Action
@export var conditions: Array[Condition] = []
