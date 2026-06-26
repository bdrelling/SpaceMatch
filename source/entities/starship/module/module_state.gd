class_name ModuleState
extends Resource
## A module's state — its type ([member blueprint]) and any per-instance runtime data. Position is NOT here: a
## module can exist outside a grid (a shop, the player's inventory), so where it sits is the grid's concern
## (see [member ModuleGridState.placements]), not the module's. Shared by reference with the [Module] node that
## represents it, so an edit through either is the same edit (no clone).

## The module's type — the shared [ModuleBlueprint] this is an instance of. A blueprint defines the type
## (shape, stats, abilities); this state is one instance of it. (Per-instance runtime data — charge, damage —
## lands here later.)
@export var blueprint: ModuleBlueprint
