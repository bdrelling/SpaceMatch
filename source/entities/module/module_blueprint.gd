class_name ModuleBlueprint
extends Resource
## Static data for a starship module: its identity, look, footprint [PieceShape], and the [StarshipStats] it
## contributes to a starship's stat profile when slotted into a [ModuleGrid]. One shared resource per
## module type.

@export var id: int = -1
@export var name: String
@export var color: Color = Color.WHITE
@export var shape: PieceShape
@export var stats: StarshipStats
## Abilities this module grants its starship — e.g. a Repair module granting a Repair ability. Aggregated into the
## starship's ability set while the module is enabled (see [method Loadout.abilities]).
@export var abilities: Array[MatchAbility] = []
## Phase rules this module grants its starship — board behaviour that rides on having the module installed.
## Aggregated into the starship's rules while the module is enabled (see [method Loadout.rules]).
@export var rules: Array[Rule] = []
