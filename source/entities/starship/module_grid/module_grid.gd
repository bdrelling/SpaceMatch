class_name ModuleGrid
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

## The placed modules as read-only projections (module + the cells it covers + whether it's enabled), for
## views and stat counting. A module is enabled unless one of its cells is in [param disabled_cells] — a
## single disabled cell deactivates the whole module that covers it.
func placed_modules(disabled_cells: Array[Vector2i] = []) -> Array[PlacedModule]:
	var result: Array[PlacedModule] = []
	if grid != null:
		for occupant: GridObjectState in grid.objects_on_layer(_LAYER):
			var module: ModuleBlueprint = occupant.state.get(_MODULE_KEY)
			result.append(PlacedModule.new(module, occupant.cells, _cells_enabled(occupant.cells, disabled_cells)))
	return result

## The stat profile this grid's modules sum to — the ship's contribution to its stats. Only modules whose
## every cell is enabled count; a module with any cell in [param disabled_cells] is deactivated and adds
## nothing. The one place the "all cells enabled to count" rule lives.
func profile(disabled_cells: Array[Vector2i] = []) -> StatBlock:
	var total := StatBlock.new()
	for placed: PlacedModule in placed_modules(disabled_cells):
		if placed.module != null and placed.enabled:
			total.add(placed.module.stats)
	return total

## The abilities this grid's enabled modules grant the ship — same "all cells enabled to count" rule as
## [method profile]. A disabled module grants nothing.
func abilities(disabled_cells: Array[Vector2i] = []) -> Array[MatchAbility]:
	var result: Array[MatchAbility] = []
	for placed: PlacedModule in placed_modules(disabled_cells):
		if placed.module != null and placed.enabled:
			result.append_array(placed.module.abilities)
	return result

## The phase rules this grid's enabled modules grant the ship — same enabled rule as [method profile].
func rules(disabled_cells: Array[Vector2i] = []) -> Array[Rule]:
	var result: Array[Rule] = []
	for placed: PlacedModule in placed_modules(disabled_cells):
		if placed.module != null and placed.enabled:
			result.append_array(placed.module.rules)
	return result

func _cells_enabled(cells: Array[Vector2i], disabled_cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		if disabled_cells.has(cell):
			return false
	return true

## A read-only projection of the module covering [param cell] (module + the cells it covers), or null
## when the cell is empty — for a host to grab a placed module by one of its cells.
func placed_at(cell: Vector2i) -> PlacedModule:
	if grid == null:
		return null
	var occupant := grid.get_object_at(_LAYER, cell.x, cell.y)
	if occupant == null:
		return null
	var module: ModuleBlueprint = occupant.state.get(_MODULE_KEY)
	return PlacedModule.new(module, occupant.cells)

## True when the module covering [param from_cell] could be translated by (to_cell - from_cell) — its
## footprint lands on usable cells and collides with nothing but itself. False when from_cell is empty.
func can_move(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if grid == null:
		return false
	var occupant := grid.get_object_at(_LAYER, from_cell.x, from_cell.y)
	if occupant == null:
		return false
	return grid.can_place(_LAYER, _translated(occupant.cells, to_cell - from_cell), occupant)

## Translates the module covering [param from_cell] by (to_cell - from_cell), preserving its rotation.
## Returns true on success; leaves the grid untouched and returns false when the move isn't valid.
func move(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not can_move(from_cell, to_cell):
		return false
	var occupant := grid.get_object_at(_LAYER, from_cell.x, from_cell.y)
	grid.remove_object(_LAYER, occupant)
	occupant.cells = _translated(occupant.cells, to_cell - from_cell)
	grid.place_object(_LAYER, occupant)
	emit_changed()
	return true

func _translated(cells: Array[Vector2i], delta: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(cell + delta)
	return result
