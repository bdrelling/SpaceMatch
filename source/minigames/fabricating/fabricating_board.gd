class_name FabricatingBoard
extends Resource
## A module's build surface for the fabricating minigame: a columns × rows grid that component footprints
## are packed into. Placement forbids collisions and out-of-bounds cells. [FabricatingGridView] draws it,
## redrawing on the built-in [signal Resource.changed] that [method place]/[method remove_at_index] fire.

@export var columns: int = 6
@export var rows: int = 6

## Placed components, parallel arrays: the component blueprint, the footprint it was placed with (cell
## offsets in authored orientation), and where/how it sits.
var pieces: Array[ItemBlueprint] = []
var footprints: Array = []  # Array of Array[Vector2i]
var placements: Array[StackPlacement] = []

func _init(_columns: int = 6, _rows: int = 6) -> void:
	columns = _columns
	rows = _rows

func tile_count() -> int:
	return columns * rows

func filled_cell_count() -> int:
	return _occupied().size()

func cell_exists(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows

## True when [param footprint] at [param anchor]/[param rotation_steps] lands entirely in bounds without
## colliding. [param excluded_index] skips one placed piece (for in-place rotation).
func can_place(footprint: Array[Vector2i], anchor: Vector2i, rotation_steps: int, excluded_index: int = -1) -> bool:
	var occupied := _occupied(excluded_index)
	for cell: Vector2i in GridGeometry.occupied_cells(footprint, anchor, rotation_steps):
		if not cell_exists(cell) or occupied.has(cell):
			return false
	return true

func place(piece: ItemBlueprint, footprint: Array[Vector2i], anchor: Vector2i, rotation_steps: int) -> bool:
	if piece == null or not can_place(footprint, anchor, rotation_steps):
		return false
	pieces.append(piece)
	footprints.append(footprint)
	placements.append(StackPlacement.new(anchor, rotation_steps))
	emit_changed()
	return true

## Index of the piece covering [param cell], or -1 when the cell is empty.
func index_at(cell: Vector2i) -> int:
	for index in placements.size():
		var footprint: Array[Vector2i] = footprints[index]
		for occupied_cell: Vector2i in GridGeometry.occupied_cells(footprint, placements[index].anchor, placements[index].rotation_steps):
			if occupied_cell == cell:
				return index
	return -1

## Removes the piece at [param index] and returns its blueprint (null when out of range).
func remove_at_index(index: int) -> ItemBlueprint:
	if index < 0 or index >= pieces.size():
		return null
	var piece: ItemBlueprint = pieces[index]
	pieces.remove_at(index)
	footprints.remove_at(index)
	placements.remove_at(index)
	emit_changed()
	return piece

func _occupied(excluded_index: int = -1) -> Dictionary[Vector2i, bool]:
	var occupied: Dictionary[Vector2i, bool] = {}
	for index in placements.size():
		if index == excluded_index:
			continue
		var footprint: Array[Vector2i] = footprints[index]
		for cell: Vector2i in GridGeometry.occupied_cells(footprint, placements[index].anchor, placements[index].rotation_steps):
			occupied[cell] = true
	return occupied
