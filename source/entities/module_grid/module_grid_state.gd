class_name ModuleGridState
extends GridState
## A starship's module-grid state — a grid_system [GridState] specialized for modules: each placed module is a
## [GridObjectState] occupant carrying its [ModuleBlueprint], and the grid derives the starship's stat profile,
## abilities, and rules from them. Pure data plus grid-level operations; the [ModuleGrid] node builds and
## represents it, and [StarshipState] persists it.

const _LAYER := 0
const _MODULE_KEY := &"module"

## The grid's column / row counts — aliases for the inherited [member GridState.width] / [member GridState.height].
var columns: int:
	get: return width
var rows: int:
	get: return height

## The placed modules' states, in placement order. The persisted source of truth a [ModuleGrid] node mirrors
## as [Module] nodes (sharing these same [ModuleState] objects by reference, so an edit through either lands
## in both). Position lives in [member placements], not on the modules.
var modules: Array[ModuleState]:
	get:
		var result: Array[ModuleState] = []
		for occupant: GridObjectState in objects_on_layer(_LAYER):
			var module_state: ModuleState = occupant.state.get(_MODULE_KEY)
			if module_state != null:
				result.append(module_state)
		return result

## Maps each placed [ModuleState] to the absolute cells it occupies on this grid — the placement layer that
## keeps modules position-free (a module in a shop/inventory has no entry here). Built from the grid's
## occupants, so it always reflects the live layout.
var placements: Dictionary:
	get:
		var result := {}
		for occupant: GridObjectState in objects_on_layer(_LAYER):
			var module_state: ModuleState = occupant.state.get(_MODULE_KEY)
			if module_state != null:
				result[module_state] = occupant.cells
		return result

## The cells [param module_state] occupies on this grid, or empty when it isn't placed here.
func cells_of(module_state: ModuleState) -> Array[Vector2i]:
	for occupant: GridObjectState in objects_on_layer(_LAYER):
		if occupant.state.get(_MODULE_KEY) == module_state:
			return occupant.cells
	return []

## The cells the module covering [param cell] occupies (its whole footprint), or empty when the cell is bare.
func cells_at(cell: Vector2i) -> Array[Vector2i]:
	var occupant := get_object_at(_LAYER, cell.x, cell.y)
	return occupant.cells if occupant != null else []

## The hull silhouette's usable cells.
func existing_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in usable_cells:
		result.append(cell)
	return result

func cell_exists(cell: Vector2i) -> bool:
	return is_usable(cell.x, cell.y)

func tile_count() -> int:
	return usable_cells.size()

func filled_cell_count() -> int:
	var count := 0
	for occupant: GridObjectState in objects_on_layer(_LAYER):
		count += occupant.cells.size()
	return count

## True when [param shape] fits at [param origin] / [param rotation] on usable, unoccupied cells. (Named to
## avoid the inherited [method GridState.can_place], which works in absolute cells rather than a shape.)
func can_place_module(shape: PieceShape, origin: Vector2i, rotation: int) -> bool:
	if shape == null:
		return false
	return can_place(_LAYER, shape.cells_at(origin, rotation))

## Places module type [param module] at [param origin] / [param rotation], building the [ModuleState] this
## grid stores for it. The occupant carries the state, so [member modules] and the grid stay one source.
func place(module: ModuleBlueprint, origin: Vector2i, rotation: int) -> bool:
	if module == null or not can_place_module(module.shape, origin, rotation):
		return false
	var cells := module.shape.cells_at(origin, rotation)
	var module_state := ModuleState.new()
	module_state.blueprint = module
	var occupant := GridObjectState.new(cells, {_MODULE_KEY: module_state})
	occupant.shape = module.shape
	occupant.shape_rotation = rotation
	place_object(_LAYER, occupant)
	emit_changed()
	return true

## The type ([ModuleBlueprint]) of the module covering [param cell], or null.
func module_at(cell: Vector2i) -> ModuleBlueprint:
	var module_state := state_at(cell)
	return module_state.blueprint if module_state != null else null

## The [ModuleState] covering [param cell], or null when the cell is empty.
func state_at(cell: Vector2i) -> ModuleState:
	var occupant := get_object_at(_LAYER, cell.x, cell.y)
	return occupant.state.get(_MODULE_KEY) if occupant != null else null

## Removes the module covering [param cell] and returns its type (null when the cell is empty).
func remove_at(cell: Vector2i) -> ModuleBlueprint:
	var occupant := get_object_at(_LAYER, cell.x, cell.y)
	if occupant == null:
		return null
	var module_state: ModuleState = occupant.state.get(_MODULE_KEY)
	remove_object(_LAYER, occupant)
	emit_changed()
	return module_state.blueprint if module_state != null else null

## True when [param module_state] is fully enabled — none of the cells it occupies is in [param
## disabled_cells]. A single disabled cell deactivates the whole module, so it stops counting toward stats.
func enabled(module_state: ModuleState, disabled_cells: Array[Vector2i] = []) -> bool:
	return _cells_enabled(cells_of(module_state), disabled_cells)

## The stat profile this grid's modules sum to — the starship's contribution to its stats. Only fully-enabled
## modules count (see [method enabled]); a module with any cell in [param disabled_cells] adds nothing. The
## one place the "all cells enabled to count" rule lives.
func profile(disabled_cells: Array[Vector2i] = []) -> StarshipStats:
	var total := StarshipStats.new()
	for occupant: GridObjectState in objects_on_layer(_LAYER):
		var module_state: ModuleState = occupant.state.get(_MODULE_KEY)
		if module_state != null and module_state.blueprint != null and _cells_enabled(occupant.cells, disabled_cells):
			total.add(module_state.blueprint.stats)
	return total

## The abilities this grid's enabled modules grant the starship — same "all cells enabled to count" rule as
## [method profile]. A disabled module grants nothing.
func abilities(disabled_cells: Array[Vector2i] = []) -> Array[MatchAbility]:
	var result: Array[MatchAbility] = []
	for occupant: GridObjectState in objects_on_layer(_LAYER):
		var module_state: ModuleState = occupant.state.get(_MODULE_KEY)
		if module_state != null and module_state.blueprint != null and _cells_enabled(occupant.cells, disabled_cells):
			result.append_array(module_state.blueprint.abilities)
	return result

## The phase rules this grid's enabled modules grant the starship — same enabled rule as [method profile].
func rules(disabled_cells: Array[Vector2i] = []) -> Array[Rule]:
	var result: Array[Rule] = []
	for occupant: GridObjectState in objects_on_layer(_LAYER):
		var module_state: ModuleState = occupant.state.get(_MODULE_KEY)
		if module_state != null and module_state.blueprint != null and _cells_enabled(occupant.cells, disabled_cells):
			result.append_array(module_state.blueprint.rules)
	return result

func _cells_enabled(cells: Array[Vector2i], disabled_cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		if disabled_cells.has(cell):
			return false
	return true

## True when the module covering [param from_cell] could be translated by (to_cell - from_cell) — its
## footprint lands on usable cells and collides with nothing but itself. False when from_cell is empty.
func can_move(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var occupant := get_object_at(_LAYER, from_cell.x, from_cell.y)
	if occupant == null:
		return false
	return can_place(_LAYER, _translated(occupant.cells, to_cell - from_cell), occupant)

## Translates the module covering [param from_cell] by (to_cell - from_cell), preserving its rotation.
## Returns true on success; leaves the grid untouched and returns false when the move isn't valid.
func move(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not can_move(from_cell, to_cell):
		return false
	var occupant := get_object_at(_LAYER, from_cell.x, from_cell.y)
	remove_object(_LAYER, occupant)
	occupant.cells = _translated(occupant.cells, to_cell - from_cell)
	place_object(_LAYER, occupant)
	emit_changed()
	return true

func _translated(cells: Array[Vector2i], delta: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(cell + delta)
	return result
