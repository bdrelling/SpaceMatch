class_name EntityResource
extends Resource
## A resource an entity holds — the engine's neutral base for anything banked in a [ResourcePool] and spent by a
## cost. Purely a definition, identified by [member name]; how much a pool may hold is the [ResourcePool]'s to set.
## Games subtype this for their own kinds (spendable "mana", currency, inventory, ...) so pools and amounts stay
## typed through the system. Distinct from a stat: a stat is a characteristic (and may govern how fast a resource
## is collected), while a resource is a pool you spend. Parallel to [EntityStat].

## Identifies this resource — the key a pool and an ability cost match on (across separate instances, by name).
@export var name: StringName
