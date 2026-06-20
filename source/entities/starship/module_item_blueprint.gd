class_name ModuleItemBlueprint
extends ItemBlueprint
## An [ItemBlueprint] for a ship module: adds the [StatBlock] the module contributes to a ship's
## stat profile when it's slotted in the bay. The base item fields (id, name, footprint, …) carry
## the module's identity and packing shape; [member stats] carries what it does.

@export var stats: StatBlock
