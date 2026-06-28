class_name Loadout
extends ModuleGridState
## A starship's loadout — its [ModuleGridState] plus the stat/ability/rule profile its placed modules sum to.
## A loadout IS a module grid (it stores and arranges modules the same way); what it adds is the derivation a
## starship cares about: the [StarshipStats] block, abilities and phase rules its enabled modules grant. That
## derivation is kept off the generic [ModuleGridState] so the grid stays reusable for things that don't have
## stats (inventories, puzzles) — only a starship's loadout turns modules into stats. [StarshipState] holds one
## as [member StarshipState.loadout]; a starship's effective stats are its base block plus this loadout's (see
## [method StarshipState.effective_stats]).

## Builds a loadout from [param blueprint] — an empty grid at the blueprint's size, stamped with its hull
## silhouette and authored modules (see [method ModuleGridState.stamp]). A null blueprint yields an empty loadout.
static func create(blueprint: ModuleGridBlueprint) -> Loadout:
	if blueprint == null:
		return Loadout.new()
	var loadout := Loadout.new(blueprint.columns, blueprint.rows, 1)
	ModuleGridState.stamp(loadout, blueprint)
	return loadout

## True when [param module_state] is fully enabled — none of the cells it occupies is in [param disabled_cells].
## A single disabled cell deactivates the whole module, so it stops counting toward stats.
func enabled(module_state: ModuleState, disabled_cells: Array[Vector2i] = []) -> bool:
	return _cells_enabled(cells_of(module_state), disabled_cells)

## The stat profile this loadout's modules sum to — the starship's contribution to its stats. Only fully-enabled
## modules count (see [method enabled]); a module with any cell in [param disabled_cells] adds nothing. The one
## place the "all cells enabled to count" rule lives.
func stats(disabled_cells: Array[Vector2i] = []) -> StarshipStats:
	var total := StarshipStats.new()
	for occupant: GridObjectState in objects_on_layer(_LAYER):
		var module_state: ModuleState = occupant.state.get(_MODULE_KEY)
		if module_state != null and module_state.blueprint != null and _cells_enabled(occupant.cells, disabled_cells):
			total.add(module_state.blueprint.stats)
	return total

## The abilities this loadout's enabled modules grant the starship — same "all cells enabled to count" rule as
## [method stats]. A disabled module grants nothing.
func abilities(disabled_cells: Array[Vector2i] = []) -> Array[MatchAbility]:
	var result: Array[MatchAbility] = []
	for occupant: GridObjectState in objects_on_layer(_LAYER):
		var module_state: ModuleState = occupant.state.get(_MODULE_KEY)
		if module_state != null and module_state.blueprint != null and _cells_enabled(occupant.cells, disabled_cells):
			result.append_array(module_state.blueprint.abilities)
	return result

## The phase rules this loadout's enabled modules grant the starship — same enabled rule as [method stats].
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
