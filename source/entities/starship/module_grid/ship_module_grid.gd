class_name ShipModuleGrid
extends Resource
## A ship's module bay: a [ShipModuleGridBlueprint] silhouette packed with module footprints.
## Placement forbids both collisions and the blueprint's missing cells. [ShipGridView] draws it,
## redrawing on the built-in [signal Resource.changed] that [method place]/[method remove_at_index] fire.

@export var blueprint: ShipModuleGridBlueprint
@export var modules: Array[ItemBlueprint] = []
@export var placements: Array[StackPlacement] = []

var columns: int:
	get: return blueprint.columns if blueprint != null else 0

var rows: int:
	get: return blueprint.rows if blueprint != null else 0

var _cell_set: Dictionary[Vector2i, bool] = {}

func _init(_blueprint: ShipModuleGridBlueprint = null) -> void:
	blueprint = _blueprint

func cell_exists(cell: Vector2i) -> bool:
	return _cells().has(cell)

func tile_count() -> int:
	return _cells().size()

func existing_cells() -> Array[Vector2i]:
	return _cells().keys()

func filled_cell_count() -> int:
	return _occupied().size()

## True when [param footprint] at [param anchor]/[param rotation_steps] lands entirely on usable
## cells without colliding with another module. [param excluded_index] skips one placed module.
func can_place(footprint: Array[Vector2i], anchor: Vector2i, rotation_steps: int, excluded_index: int = -1) -> bool:
	var occupied := _occupied(excluded_index)
	for cell: Vector2i in GridGeometry.occupied_cells(footprint, anchor, rotation_steps):
		if not _cells().has(cell) or occupied.has(cell):
			return false
	return true

func place(module: ItemBlueprint, anchor: Vector2i, rotation_steps: int) -> bool:
	if module == null or not can_place(module.footprint_cells, anchor, rotation_steps):
		return false
	modules.append(module)
	placements.append(StackPlacement.new(anchor, rotation_steps))
	emit_changed()
	return true

## Index of the module covering [param cell], or -1 when the cell is empty.
func index_at(cell: Vector2i) -> int:
	for index in placements.size():
		for occupied_cell: Vector2i in GridGeometry.occupied_cells(modules[index].footprint_cells, placements[index].anchor, placements[index].rotation_steps):
			if occupied_cell == cell:
				return index
	return -1

## Removes the module at [param index] and returns it (null when out of range).
func remove_at_index(index: int) -> ItemBlueprint:
	if index < 0 or index >= modules.size():
		return null
	var module := modules[index]
	modules.remove_at(index)
	placements.remove_at(index)
	emit_changed()
	return module

# Usable cells, cached from the blueprint silhouette.
func _cells() -> Dictionary[Vector2i, bool]:
	if _cell_set.is_empty() and blueprint != null:
		for cell: Vector2i in blueprint.cells:
			_cell_set[cell] = true
	return _cell_set

# Cells claimed by every placed module, skipping [param excluded_index].
func _occupied(excluded_index: int = -1) -> Dictionary[Vector2i, bool]:
	var occupied: Dictionary[Vector2i, bool] = {}
	for index in placements.size():
		if index == excluded_index:
			continue
		for cell: Vector2i in GridGeometry.occupied_cells(modules[index].footprint_cells, placements[index].anchor, placements[index].rotation_steps):
			occupied[cell] = true
	return occupied
