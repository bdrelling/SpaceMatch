class_name GridCapacityRule
extends CapacityRule
## Caps contents spatially: every stack occupies its footprint on a width x height grid.
## Topping up an existing stack claims no new cells; each new stack needs a valid placement.

@export var width: int = 1
@export var height: int = 1
## Rows from the top that only accept single-cell footprints (e.g. a quickbar row).
## Multi-cell shapes may not overlap them; 1x1 stacks place freely.
@export var single_cell_rows: int = 0

func can_add(state: InventoryState, item_blueprint: ItemBlueprint, _amount: int, new_stack_count: int) -> bool:
	if new_stack_count <= 0:
		return true
	return not find_placements(state, item_blueprint, new_stack_count).is_empty()

## First-fit placements for [param count] new stacks of the footprint, in order; empty when
## they don't all fit.
func find_placements(state: InventoryState, item_blueprint: ItemBlueprint, count: int) -> Array[StackPlacement]:
	var occupied := blocked_cell_set(state, item_blueprint.footprint_cells)
	var placements: Array[StackPlacement] = []
	for index in count:
		var placement := GridGeometry.find_placement(item_blueprint.footprint_cells, width, height, occupied)
		if placement == null:
			return []
		for cell: Vector2i in GridGeometry.occupied_cells(item_blueprint.footprint_cells, placement.anchor, placement.rotation_steps):
			occupied[cell] = true
		placements.append(placement)
	return placements

## Set of cells claimed by the current placements. [param excluded_index] skips one stack,
## for collision tests that move it.
func occupied_cell_set(state: InventoryState, excluded_index: int = -1) -> Dictionary[Vector2i, bool]:
	var occupied: Dictionary[Vector2i, bool] = {}
	for index in mini(state.stacks.size(), state.placements.size()):
		if index == excluded_index:
			continue
		var placement: StackPlacement = state.placements[index]
		var stack: ItemStack = state.stacks[index]
		if placement == null or stack.item_blueprint == null:
			continue
		for cell: Vector2i in GridGeometry.occupied_cells(stack.item_blueprint.footprint_cells, placement.anchor, placement.rotation_steps):
			occupied[cell] = true
	return occupied

## [method occupied_cell_set] plus every [member single_cell_rows] cell when [param footprint]
## spans more than one cell — multi-cell shapes treat the restricted rows as solid.
func blocked_cell_set(state: InventoryState, footprint: Array[Vector2i], excluded_index: int = -1) -> Dictionary[Vector2i, bool]:
	var blocked := occupied_cell_set(state, excluded_index)
	if footprint.size() <= 1:
		return blocked
	for y in mini(single_cell_rows, height):
		for x in width:
			blocked[Vector2i(x, y)] = true
	return blocked

func describe(state: InventoryState) -> String:
	return "%d / %d" % [occupied_cell_set(state).size(), width * height]
