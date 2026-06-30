class_name AbilityResource
extends Resource
## A spendable resource an ability can cost — the engine's neutral "mana" base (energy, ammo, a tile economy).
## Games extend or author this to define their own resource kinds; an entity holds how much of each it has and
## abilities spend amounts of them. Purely a definition: how much a pool may hold is the [ResourcePool]'s to set,
## not the resource's. Distinct from a stat: a stat is a characteristic (and may govern how fast a resource is
## collected), while a resource is a pool you spend.

## Identifies this resource — used by ability costs and an entity's per-resource amounts.
@export var name: StringName
