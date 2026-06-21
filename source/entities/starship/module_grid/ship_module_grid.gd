class_name ShipModuleGrid
extends Resource
## A ship's module grid: a grid_system [GridState] (its silhouette plus the modules packed into it)
## wrapped in a module-level API. The grid owns placement — a placed module is a [GridObjectState]
## occupant whose state carries the [ModuleBlueprint]. Persists with the save via [member grid].

const _LAYER := 0
const _MODULE_KEY := &"module"

@export var grid: GridState

var columns: int:
	get:
		return grid.width if grid != null else 0

var rows: int:
	get:
		return grid.height if grid != null else 0

## The hull silhouette's usable cells.
func existing_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid != null:
		for cell: Vector2i in grid.usable_cells:
			result.append(cell)
	return result

func cell_exists(cell: Vector2i) -> bool:
	return grid != null and grid.is_usable(cell.x, cell.y)

func tile_count() -> int:
	return grid.usable_cells.size() if grid != null else 0

func filled_cell_count() -> int:
	var count := 0
	if grid != null:
		for occupant: GridObjectState in grid.objects_on_layer(_LAYER):
			count += occupant.cells.size()
	return count

func can_place(shape: PieceShape, origin: Vector2i, rotation: int) -> bool:
	if grid == null or shape == null:
		return false
	return grid.can_place(_LAYER, shape.cells_at(origin, rotation))

func place(module: ModuleBlueprint, origin: Vector2i, rotation: int) -> bool:
	if module == null or not can_place(module.shape, origin, rotation):
		return false
	var occupant := GridObjectState.new(module.shape.cells_at(origin, rotation), {_MODULE_KEY: module})
	occupant.shape = module.shape
	occupant.shape_rotation = rotation
	grid.place_object(_LAYER, occupant)
	emit_changed()
	return true

## The module covering [param cell], or null.
func module_at(cell: Vector2i) -> ModuleBlueprint:
	if grid == null:
		return null
	var occupant := grid.get_object_at(_LAYER, cell.x, cell.y)
	if occupant == null:
		return null
	var module: ModuleBlueprint = occupant.state.get(_MODULE_KEY)
	return module

## Removes and returns the module covering [param cell] (null when the cell is empty).
func remove_at(cell: Vector2i) -> ModuleBlueprint:
	if grid == null:
		return null
	var occupant := grid.get_object_at(_LAYER, cell.x, cell.y)
	if occupant == null:
		return null
	var module: ModuleBlueprint = occupant.state.get(_MODULE_KEY)
	grid.remove_object(_LAYER, occupant)
	emit_changed()
	return module

## The placed modules as read-only projections (module + the cells it covers), for views.
func placed_modules() -> Array[PlacedModule]:
	var result: Array[PlacedModule] = []
	if grid != null:
		for occupant: GridObjectState in grid.objects_on_layer(_LAYER):
			var module: ModuleBlueprint = occupant.state.get(_MODULE_KEY)
			result.append(PlacedModule.new(module, occupant.cells))
	return result
