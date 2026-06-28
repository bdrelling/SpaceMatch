class_name ModuleGridBlueprint
extends Resource
## Authored preset for a module grid: the bay's dimensions and usable-cell silhouette. Pure data —
## [method ModuleGrid.create] reads it to build a [ModuleGrid].

@export var columns: int = 6
@export var rows: int = 6
## The usable (hull) cells of the silhouette. Empty means the whole columns x rows rectangle.
@export var cells: Array[Vector2i] = []
## Modules the bay starships with, stamped into the grid in order by [method ModuleGrid.create]. A placement
## that doesn't fit (off-silhouette or overlapping an earlier one) is skipped.
@export var modules: Array[ModulePlacement] = []
