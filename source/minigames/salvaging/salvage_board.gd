class_name SalvageBoard
extends RefCounted
## Logic-only field for the salvaging minigame: a minesweeper grid of hidden objects, each safe cell
## stamped with its count of neighbouring objects, plus reveal / flood / flag operations. Mode-agnostic
## — the host minigame decides whether a hidden object is a hazard to avoid (minesweeper) or loot to
## claim (salvage mode). No rendering, no win rules; those live in the host.

## Outcome of revealing one cell: nothing happened (out of bounds / already open), a safe cell opened,
## or a hidden object was uncovered.
enum Reveal { NONE, SAFE, OBJECT }

var width: int
var height: int
## How many hidden objects the field scatters.
var object_count: int

var _state: GridBoardState
var _rng := RandomNumberGenerator.new()
var _revealed_safe: int = 0

func _init(grid_width: int, grid_height: int, hidden_objects: int) -> void:
	width = grid_width
	height = grid_height
	object_count = hidden_objects

## (Re)builds the field: clears every cell, scatters [member object_count] hidden objects, then stamps
## each safe cell with its neighbouring-object count. A non-zero [param seed] replays the same field;
## zero rolls a fresh one.
func generate(seed_value: int) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_state = GridBoardState.new(width, height, 1)
	for y: int in height:
		for x: int in width:
			_state.place_object(0, Cell.new([Vector2i(x, y)]))
	var placed: int = 0
	while placed < object_count:
		var spot := cell_at(_rng.randi_range(0, width - 1), _rng.randi_range(0, height - 1))
		if spot.object:
			continue
		spot.object = true
		placed += 1
	for y: int in height:
		for x: int in width:
			var cell := cell_at(x, y)
			if not cell.object:
				cell.adjacent = _count_adjacent(x, y)
	_revealed_safe = 0

## Writes the current field into [param state]'s flat arrays so it can be saved. Touches only the
## field's own data — never the host's mode or run rules.
func capture(state: SalvagingState) -> void:
	var size: int = width * height
	state.width = width
	state.height = height
	state.object_count = object_count
	var objects := PackedByteArray()
	var revealed := PackedByteArray()
	var flagged := PackedByteArray()
	var adjacent := PackedInt32Array()
	objects.resize(size)
	revealed.resize(size)
	flagged.resize(size)
	adjacent.resize(size)
	for y: int in height:
		for x: int in width:
			var index: int = y * width + x
			var cell := cell_at(x, y)
			objects[index] = 1 if cell.object else 0
			revealed[index] = 1 if cell.revealed else 0
			flagged[index] = 1 if cell.flagged else 0
			adjacent[index] = cell.adjacent
	state.objects = objects
	state.revealed = revealed
	state.flagged = flagged
	state.adjacent = adjacent
	state.revealed_safe = _revealed_safe

## Rebuilds the field from [param state]'s saved arrays — the exact same cells, no RNG roll.
func restore(state: SalvagingState) -> void:
	width = state.width
	height = state.height
	object_count = state.object_count
	_state = GridBoardState.new(width, height, 1)
	for y: int in height:
		for x: int in width:
			var index: int = y * width + x
			var cell := Cell.new([Vector2i(x, y)])
			cell.object = state.objects[index] != 0
			cell.revealed = state.revealed[index] != 0
			cell.flagged = state.flagged[index] != 0
			cell.adjacent = state.adjacent[index]
			_state.place_object(0, cell)
	_revealed_safe = state.revealed_safe

func cell_at(x: int, y: int) -> Cell:
	return _state.get_object_at(0, x, y) as Cell

func in_bounds(x: int, y: int) -> bool:
	return _state.in_bounds(x, y)

## Reveals [param cell]: a hidden object opens just that cell and returns [code]OBJECT[/code]; a safe
## cell flood-opens its empty neighbourhood and returns [code]SAFE[/code]. Returns [code]NONE[/code]
## (no change) when the cell is out of bounds or already open. Ignores flags — the host decides whether
## a flag blocks revealing.
func reveal(cell: Vector2i) -> Reveal:
	var data := cell_at(cell.x, cell.y)
	if data == null or data.revealed:
		return Reveal.NONE
	if data.object:
		data.revealed = true
		return Reveal.OBJECT
	_flood_reveal(cell)
	return Reveal.SAFE

## Reveals exactly [param cell] with no flood spill — the salvage-hunt dig, where one tap opens one
## cell. Returns [code]OBJECT[/code] / [code]SAFE[/code] like [method reveal], or [code]NONE[/code] when
## the cell is out of bounds or already open.
func reveal_single(cell: Vector2i) -> Reveal:
	var data := cell_at(cell.x, cell.y)
	if data == null or data.revealed:
		return Reveal.NONE
	data.revealed = true
	if data.object:
		return Reveal.OBJECT
	_revealed_safe += 1
	return Reveal.SAFE

func toggle_flag(cell: Vector2i) -> void:
	var data := cell_at(cell.x, cell.y)
	if data == null or data.revealed:
		return
	data.flagged = not data.flagged

## Opens every hidden object — the host calls this to expose the field on a loss.
func reveal_all_objects() -> void:
	for y: int in height:
		for x: int in width:
			var cell := cell_at(x, y)
			if cell.object:
				cell.revealed = true

## Marks one cell revealed unconditionally — drives the end-of-field reveal sweep, ignoring objects,
## flags, and flood rules.
func expose(cell: Vector2i) -> void:
	var data := cell_at(cell.x, cell.y)
	if data != null:
		data.revealed = true

## How many cells are currently flagged.
func flag_count() -> int:
	var flags: int = 0
	for y: int in height:
		for x: int in width:
			if cell_at(x, y).flagged:
				flags += 1
	return flags

## Total safe cells on the field.
func safe_total() -> int:
	return width * height - object_count

## Safe cells opened so far.
func revealed_safe() -> int:
	return _revealed_safe

## True once every safe cell is open — the classic minesweeper clear.
func is_cleared() -> bool:
	return _revealed_safe >= safe_total()

## True when flags cover exactly the hidden objects and nothing else — the "flag every mine" win.
func all_objects_flagged() -> bool:
	var flags: int = 0
	for y: int in height:
		for x: int in width:
			var cell := cell_at(x, y)
			if cell.flagged:
				if not cell.object:
					return false
				flags += 1
	return flags == object_count

# Iterative flood: open the cell; if it borders no objects, spill into its eight neighbours — the
# classic minesweeper open. Objects and flagged cells stop the spill.
func _flood_reveal(start: Vector2i) -> void:
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var here: Vector2i = stack.pop_back()
		var cell := cell_at(here.x, here.y)
		if cell == null or cell.revealed or cell.flagged or cell.object:
			continue
		cell.revealed = true
		_revealed_safe += 1
		if cell.adjacent != 0:
			continue
		for neighbor: Vector2i in _state.neighbors_8(here.x, here.y):
			stack.push_back(neighbor)

func _count_adjacent(x: int, y: int) -> int:
	var count: int = 0
	for neighbor: Vector2i in _state.neighbors_8(x, y):
		if cell_at(neighbor.x, neighbor.y).object:
			count += 1
	return count

## One cell of the field: hidden object or not, covered until revealed, optionally flagged, carrying
## its neighbouring-object count once the field is generated.
class Cell extends BoardObjectState:
	var object: bool = false
	var revealed: bool = false
	var flagged: bool = false
	var adjacent: int = 0

	func _init(occupied_cells: Array[Vector2i] = []) -> void:
		super(occupied_cells)
