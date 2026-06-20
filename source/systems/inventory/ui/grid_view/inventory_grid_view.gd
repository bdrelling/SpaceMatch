class_name InventoryGridView
extends Control
## Renders an [Inventory] with a [GridCapacityRule]: a grid of cells with one
## [InventoryStackTile] per stack, spanning its footprint. Mouse input maps to inventory
## cell coordinates and surfaces as [signal cell_pressed] / [signal cell_hovered]; an
## owning panel drives placement. Renders a row subrange, so the same view draws a
## one-row quickbar or the whole grid.

const SCENE_PATH := "res://systems/inventory/ui/grid_view/inventory_grid_view.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

const _PALETTE := preload("res://systems/design/rustyard.tres")

const _VALID_PREVIEW_COLOR := Color(0.45, 0.85, 0.45, 0.4)
const _INVALID_PREVIEW_COLOR := Color(0.9, 0.35, 0.3, 0.4)
const _SELECTION_COLOR := Color(0.95, 0.9, 0.75, 0.9)

signal cell_pressed(cell: Vector2i)
signal cell_hovered(cell: Vector2i)

## First inventory row to render.
@export var first_row: int = 0
## Rows to render from [member first_row] down; 0 means every remaining row.
@export var row_count: int = 0
@export var cell_size: int = 48
@export var cell_separation: int = 4
## Extra gap drawn below the rule's single-cell rows, visually splitting the quickbar row
## from the rest of the grid. Only applies when the rendered range spans that boundary.
@export var section_separation: int = 0

var inventory: Inventory

## Column highlighted on the first rendered row (quickbar selection); -1 for none.
var selected_column: int = -1:
	set(value):
		selected_column = value
		queue_redraw()

var _held_stack: ItemStack
var _preview_cells: Array[Vector2i] = []
var _preview_valid := false
var _hovered_cell := Vector2i(-1, -1)

@onready var _tiles: Control = %Tiles

func _ready() -> void:
	_refresh_minimum_size()
	_rebuild()

## Sets the [Inventory] to display, (re)connecting the [signal Inventory.changed] listener
## and rebuilding. Pass null to clear.
func register(value: Inventory) -> void:
	if inventory == value:
		return
	if inventory and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = value
	if inventory and not inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.connect(_on_inventory_changed)
	if is_node_ready():
		_refresh_minimum_size()
		_rebuild()

## Ghosts [param stack]'s tile in place while the cursor previews its destination.
## Pass null to clear.
func set_held_stack(stack: ItemStack) -> void:
	_held_stack = stack
	_apply_held_ghost()
	if stack == null:
		clear_preview()

## Tints [param cells] as the held stack's destination, green when [param valid].
func set_preview(cells: Array[Vector2i], valid: bool) -> void:
	_preview_cells = cells
	_preview_valid = valid
	queue_redraw()

func clear_preview() -> void:
	_preview_cells = []
	queue_redraw()

func column_count() -> int:
	var rule := _grid_rule()
	return rule.width if rule != null else 0

func _grid_rule() -> GridCapacityRule:
	return (inventory.capacity_rule as GridCapacityRule) if inventory != null else null

func _visible_row_count() -> int:
	var rule := _grid_rule()
	if rule == null:
		return 0
	var remaining := rule.height - first_row
	return clampi(row_count if row_count > 0 else remaining, 0, remaining)

func _pitch() -> int:
	return cell_size + cell_separation

# Extra vertical gap pushed onto [param global_row]'s cells: the section gap once the row
# sits past the rule's single-cell rows, when this view renders across that boundary.
func _section_gap_for_row(global_row: int) -> int:
	var rule := _grid_rule()
	if rule == null or section_separation <= 0:
		return 0
	if first_row >= rule.single_cell_rows or global_row < rule.single_cell_rows:
		return 0
	return section_separation

func _refresh_minimum_size() -> void:
	var rule := _grid_rule()
	if rule == null:
		custom_minimum_size = Vector2.ZERO
		return
	var rows := _visible_row_count()
	custom_minimum_size = Vector2(
		rule.width * _pitch() - cell_separation,
		rows * _pitch() - cell_separation + _section_gap_for_row(first_row + rows - 1))

func _on_inventory_changed(_inventory: Inventory) -> void:
	_rebuild()

func _rebuild() -> void:
	for child in _tiles.get_children():
		child.queue_free()
	queue_redraw()
	var rule := _grid_rule()
	if rule == null:
		return
	var stacks := inventory.get_stacks()
	var placements := inventory.get_placements()
	var last_row := first_row + _visible_row_count() - 1
	for index in mini(stacks.size(), placements.size()):
		var placement: StackPlacement = placements[index]
		if placement.anchor.y < first_row or placement.anchor.y > last_row:
			continue
		var tile := InventoryStackTile.create(stacks[index], placement, cell_size, cell_separation, first_row)
		# Multi-cell shapes never straddle the single-cell boundary, so one offset fits the tile.
		tile.position.y += _section_gap_for_row(placement.anchor.y)
		_tiles.add_child(tile)
	_apply_held_ghost()

func _apply_held_ghost() -> void:
	for child in _tiles.get_children():
		var tile := child as InventoryStackTile
		if tile != null:
			tile.modulate.a = 0.45 if _held_stack != null and tile.stack == _held_stack else 1.0

func _draw() -> void:
	var rule := _grid_rule()
	if rule == null:
		return
	var rows := _visible_row_count()
	for row in rows:
		for column in rule.width:
			var rect := _cell_rect(Vector2i(column, row))
			draw_rect(rect, _PALETTE.sidebar_slot_background)
			draw_rect(rect, _PALETTE.sidebar_slot_border, false, 1.0)
	if selected_column >= 0 and selected_column < rule.width and rows > 0:
		draw_rect(_cell_rect(Vector2i(selected_column, 0)), _SELECTION_COLOR, false, 2.0)
	for cell: Vector2i in _preview_cells:
		var local_cell := Vector2i(cell.x, cell.y - first_row)
		if local_cell.x < 0 or local_cell.x >= rule.width or local_cell.y < 0 or local_cell.y >= rows:
			continue
		draw_rect(_cell_rect(local_cell), _VALID_PREVIEW_COLOR if _preview_valid else _INVALID_PREVIEW_COLOR)

# Rect of a visible cell, addressed in local row space.
func _cell_rect(local_cell: Vector2i) -> Rect2:
	var y := local_cell.y * _pitch() + _section_gap_for_row(local_cell.y + first_row)
	return Rect2(Vector2(local_cell.x * _pitch(), y), Vector2(cell_size, cell_size))

func _gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_at(mouse_button.position)
		if cell.x != -1:
			cell_pressed.emit(cell)
			accept_event()
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null:
		var cell := _cell_at(mouse_motion.position)
		if cell != _hovered_cell:
			_hovered_cell = cell
			if cell.x != -1:
				cell_hovered.emit(cell)

# Inventory-space cell under [param local_position], or (-1, -1) outside any cell. Walks
# the drawn rects so hit-testing always matches rendering, section gap included.
func _cell_at(local_position: Vector2) -> Vector2i:
	var rule := _grid_rule()
	if rule == null:
		return Vector2i(-1, -1)
	for row in _visible_row_count():
		for column in rule.width:
			if _cell_rect(Vector2i(column, row)).has_point(local_position):
				return Vector2i(column, row + first_row)
	return Vector2i(-1, -1)
