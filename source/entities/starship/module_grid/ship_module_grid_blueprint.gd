class_name ShipModuleGridBlueprint
extends Resource
## Authored shape of a ship's module bay: a [member columns]x[member rows] bounds where only
## [member cells] are usable, carving the hull silhouette.

@export var columns: int = 6
@export var rows: int = 6
@export var cells: Array[Vector2i] = []

func create() -> ShipModuleGrid:
	return ShipModuleGrid.new(self)
