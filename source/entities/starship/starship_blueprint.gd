class_name StarshipBlueprint
extends Resource
## Authored preset for a starship: its name and module-grid layout. Pure data — a [StarshipGenerator]
## reads it to build a [StarshipState].

@export var name: String = ""
@export var module_grid: ModuleGridBlueprint
