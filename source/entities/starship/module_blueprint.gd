class_name ModuleBlueprint
extends Resource
## Static data for a ship module: its identity, look, footprint [PieceShape], and the [StatBlock] it
## contributes to a ship's stat profile when slotted into a [ShipModuleGrid]. One shared resource per
## module type.

@export var id: int = -1
@export var name: String
@export var color: Color = Color.WHITE
@export var shape: PieceShape
@export var stats: StatBlock
