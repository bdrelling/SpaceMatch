class_name ResourcePool
extends Resource
## How much of one [AbilityResource] an [Entity] currently holds — the live counterpart of the resource definition
## (an [AbilityResource] is the kind; this is the amount on hand). Spent by [ResourceEngine] to pay a [ResourceCost]
## and refilled as the game collects.

@export var resource: AbilityResource
@export var amount: int = 0
## The most this pool may hold; 0 means fall back to the resource's [member AbilityResource.maximum] (itself 0 =
## unlimited). Lets the host cap a specific pool — e.g. a per-encounter ceiling — above or below the kind's own.
@export var maximum: int = 0
