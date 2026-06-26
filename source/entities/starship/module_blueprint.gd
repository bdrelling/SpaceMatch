class_name ModuleBlueprint
extends Resource
## Static data for a ship module: its identity, look, footprint [PieceShape], and the [StatBlock] it
## contributes to a ship's stat profile when slotted into a [ModuleGrid]. One shared resource per
## module type.

@export var id: int = -1
@export var name: String
@export var color: Color = Color.WHITE
@export var shape: PieceShape
@export var stats: StatBlock
## Abilities this module grants its ship — e.g. a Repair module granting a Repair ability. Aggregated into the
## ship's ability set while the module is enabled (see [method ModuleGridState.abilities]).
@export var abilities: Array[MatchAbility] = []
## Phase rules this module grants its ship — board behaviour that rides on having the module installed.
## Aggregated into the ship's rules while the module is enabled (see [method ModuleGridState.rules]).
@export var rules: Array[Rule] = []
