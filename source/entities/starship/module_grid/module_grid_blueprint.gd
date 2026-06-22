class_name ModuleGridBlueprint
extends Resource
## Authored preset for a module grid: the bay's dimensions and usable-cell silhouette. Pure data — a
## [ModuleGridGenerator] reads it to build a [ModuleGrid].

@export var columns: int = 6
@export var rows: int = 6
## The usable (hull) cells of the silhouette. Empty means the whole columns x rows rectangle.
@export var cells: Array[Vector2i] = []
