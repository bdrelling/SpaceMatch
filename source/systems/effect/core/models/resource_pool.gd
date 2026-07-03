class_name ResourcePool
extends Resource
## How much of one [EntityResource] an [Entity] currently holds — the live counterpart of the resource definition
## (an [EntityResource] is the kind; this is the amount on hand). Spent by [ResourceEngine] to pay a [ResourceCost]
## and refilled as the game collects.

@export var resource: EntityResource
@export var amount: int = 0
## The most this pool may hold; 0 means unlimited. The pool — not the resource definition — owns its ceiling, so
## the host can cap a specific pool (e.g. a per-encounter capacity) without touching the shared [EntityResource].
@export var maximum: int = 0
