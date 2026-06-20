class_name GridGeometry
extends RefCounted
## Stateless footprint math for grid inventories: rotation, occupancy, and first-fit placement.
## Footprints are cell offsets whose anchor is the top-left of their bounding box.

## [param cells] rotated [param rotation_steps] quarter turns clockwise, then shifted so the
## minimum x/y is zero — the anchor stays the top-left of the rotated bounding box.
static func rotate_cells(cells: Array[Vector2i], rotation_steps: int) -> Array[Vector2i]:
	var steps := posmod(rotation_steps, 4)
	var rotated: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var result := cell
		for step in steps:
			result = Vector2i(-result.y, result.x)
		rotated.append(result)
	return _normalized(rotated)

## Grid cells a footprint claims with its anchor at [param anchor].
static func occupied_cells(cells: Array[Vector2i], anchor: Vector2i, rotation_steps: int) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for cell: Vector2i in rotate_cells(cells, rotation_steps):
		occupied.append(anchor + cell)
	return occupied

## True when every claimed cell lies inside a [param width] x [param height] grid and none
## collides with [param occupied].
static func fits(cells: Array[Vector2i], anchor: Vector2i, rotation_steps: int, width: int, height: int, occupied: Dictionary[Vector2i, bool]) -> bool:
	for cell: Vector2i in occupied_cells(cells, anchor, rotation_steps):
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			return false
		if occupied.has(cell):
			return false
	return true

## First placement that fits, preferring the authored orientation: each rotation is scanned
## across the whole grid row-major before trying the next. Null when nothing fits.
static func find_placement(cells: Array[Vector2i], width: int, height: int, occupied: Dictionary[Vector2i, bool]) -> StackPlacement:
	for rotation_steps in 4:
		for y in height:
			for x in width:
				if fits(cells, Vector2i(x, y), rotation_steps, width, height, occupied):
					return StackPlacement.new(Vector2i(x, y), rotation_steps)
	return null

static func _normalized(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return cells
	var minimum: Vector2i = cells[0]
	for cell: Vector2i in cells:
		minimum = Vector2i(mini(minimum.x, cell.x), mini(minimum.y, cell.y))
	var shifted: Array[Vector2i] = []
	for cell: Vector2i in cells:
		shifted.append(cell - minimum)
	return shifted
