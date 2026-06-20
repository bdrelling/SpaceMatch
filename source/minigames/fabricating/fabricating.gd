class_name FabricatingMinigame
extends Minigame
## Fabricating minigame (grid packing). The player picks a recipe, then packs the components it calls for
## into the module's build grid: tap a component in the tray to pick it up, drag across the grid to place
## its footprint ([FabricatingGridView] previews the fit), right-click / two-finger tap to rotate, lift to
## set it. Tap a placed piece with nothing held to pull it back. Packing every required component
## fabricates the module and drops it into the outpost's salvage yard, then the player picks the next
## recipe on a fresh grid. Each component is a real [ItemBlueprint] (wire, tube, panel, bolt, gear, coil)
## with its own footprint shape.

const _CELL_SIZE: float = 96.0
const _KIND_COUNT: int = 6

## Component catalog, indexed by kind — the single source for each kind's identity and colour.
const _COMPONENTS: Array[ItemBlueprint] = [
	preload("res://resources/items/components/wire_item_blueprint.tres"),
	preload("res://resources/items/components/tube_item_blueprint.tres"),
	preload("res://resources/items/components/panel_item_blueprint.tres"),
	preload("res://resources/items/components/bolt_item_blueprint.tres"),
	preload("res://resources/items/components/gear_item_blueprint.tres"),
	preload("res://resources/items/components/coil_item_blueprint.tres"),
]

## Footprint per kind (cell offsets, authored orientation) — the shape each component packs as. Kept here
## rather than on the shared component resources so the board's shapes stay a fabricating concern.
const _FOOTPRINTS: Array = [
	[Vector2i(0, 0)],                                                   # wire — 1x1
	[Vector2i(0, 0), Vector2i(1, 0)],                                   # tube — 1x2
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],   # panel — 2x2
	[Vector2i(0, 0)],                                                   # bolt — 1x1
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],   # gear — 2x2
	[Vector2i(0, 0), Vector2i(1, 0)],                                   # coil — 1x2
]

const _REACTOR: ItemBlueprint = preload("res://resources/items/modules/reactor_item_blueprint.tres")
const _ENGINE: ItemBlueprint = preload("res://resources/items/modules/engine_item_blueprint.tres")
const _THRUSTER: ItemBlueprint = preload("res://resources/items/modules/thruster_item_blueprint.tres")
const _FUEL_TANK: ItemBlueprint = preload("res://resources/items/modules/fuel_tank_item_blueprint.tres")
const _CARGO_BAY: ItemBlueprint = preload("res://resources/items/modules/cargo_bay_item_blueprint.tres")
const _LIFE_SUPPORT: ItemBlueprint = preload("res://resources/items/modules/life_support_item_blueprint.tres")
const _ARMOR_PLATING: ItemBlueprint = preload("res://resources/items/modules/armor_plating_item_blueprint.tres")
const _SHIELD_GENERATOR: ItemBlueprint = preload("res://resources/items/modules/shield_generator_item_blueprint.tres")
const _SENSOR_ARRAY: ItemBlueprint = preload("res://resources/items/modules/sensor_array_item_blueprint.tres")

## Footprint size for the recipe icon on a selection card.
const _CARD_ICON_SIZE := Vector2(96, 96)

@onready var _canvas: BoardCanvas = %BoardCanvas

var _message: String = ""

var _board: FabricatingBoard
var _view: FabricatingGridView
var _tray: ComponentTray

# Recipe selection + progress.
var _recipes: Array[_Recipe] = []
var _selected_recipe: _Recipe
# Components still to place per kind for the selected recipe; 0 for kinds it doesn't need.
var _remaining: Array[int] = []
var _complete: bool = false

# Held component being positioned on the board.
var _held_kind: int = -1
var _held_rotation: int = 0
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _positioning: bool = false

# The outpost salvage yard finished modules drop into, when bound to a running game.
var _salvage_yard: Inventory

var _selection_overlay: Control
var _selection_title: Label

func _ready() -> void:
	_build_recipes()
	_build_selection_overlay()
	_show_selection()
	_message = "Select a recipe to begin."
	_compose_status()

## Reset re-empties the current recipe's grid; Change Recipe returns to the picker.
func actions() -> Array[MinigameAction]:
	var list: Array[MinigameAction] = [
		MinigameAction.new("Reset Grid", _on_reset_pressed),
		MinigameAction.new("Change Recipe", _show_selection),
	]
	return list

## Binds the minigame to the running game's outpost, so fabricated modules drop into its salvage yard
## (the shared economy). Called by [MinigameScreen] when the arcade mounts this page.
func bind_session(_game_session: GameSession, _inventory: Inventory) -> void:
	var yard_state := _yard_state(_game_session)
	if yard_state == null:
		return
	if _salvage_yard == null:
		_salvage_yard = Inventory.new()
		add_child(_salvage_yard)
	_salvage_yard.bind(yard_state)

func _yard_state(session: GameSession) -> InventoryState:
	if session == null or session.state == null or session.state.outpost == null:
		return null
	return session.state.outpost.salvage_yard

#region View-model

func inventory_chips() -> Array[InventoryChip]:
	return []

func inventory_detail() -> Control:
	if _tray == null:
		_tray = ComponentTray.new()
		_tray.component_picked.connect(_on_component_picked)
		_rebuild_tray()
	return _tray

func inventory_pinned() -> bool:
	return true

#endregion

#region Recipes

func _build_recipes() -> void:
	# Component kinds, indexing _COMPONENTS: 0 wire, 1 tube, 2 panel, 3 bolt, 4 gear, 5 coil.
	_recipes.clear()
	_recipes.append(_make_recipe(_REACTOR, {2: 2, 0: 2, 5: 1}))
	_recipes.append(_make_recipe(_ENGINE, {2: 2, 1: 2, 4: 1}))
	_recipes.append(_make_recipe(_THRUSTER, {1: 1, 0: 1}))
	_recipes.append(_make_recipe(_FUEL_TANK, {2: 2, 1: 1}))
	_recipes.append(_make_recipe(_CARGO_BAY, {2: 3, 3: 2}))
	_recipes.append(_make_recipe(_LIFE_SUPPORT, {2: 1, 1: 2, 0: 1}))
	_recipes.append(_make_recipe(_ARMOR_PLATING, {2: 2, 3: 2}))
	_recipes.append(_make_recipe(_SHIELD_GENERATOR, {0: 2, 5: 1, 2: 1}))
	_recipes.append(_make_recipe(_SENSOR_ARRAY, {0: 1, 5: 1}))

func _make_recipe(module: ItemBlueprint, requirements: Dictionary) -> _Recipe:
	var per_kind: Array[int] = []
	per_kind.resize(_KIND_COUNT)
	per_kind.fill(0)
	for kind: int in requirements:
		per_kind[kind] = requirements[kind]
	return _Recipe.new(module, per_kind)

func _on_recipe_chosen(recipe: _Recipe) -> void:
	_selected_recipe = recipe
	_remaining = recipe.requirements.duplicate()
	_complete = false
	_cancel_hold()
	_selection_overlay.visible = false
	_build_board()
	_rebuild_tray()
	_show_play_status()
	inventory_changed.emit()

func _total_remaining() -> int:
	var total: int = 0
	for count: int in _remaining:
		total += count
	return total

func _is_recipe_complete() -> bool:
	return _selected_recipe != null and _total_remaining() == 0

# Fabricates the module: drops it into the salvage yard, then returns the player to the picker.
func _on_recipe_complete() -> void:
	_complete = true
	_deposit_module(_selected_recipe.module)
	_message = "Fabricated a %s — sent to the salvage yard." % _selected_recipe.module.name
	_compose_status()
	_show_selection()

func _deposit_module(module: ItemBlueprint) -> void:
	if _salvage_yard != null and module != null:
		_salvage_yard.add_variant(module, [], 1)

#endregion

#region Board

func _build_board() -> void:
	var size := _board_size_for_recipe()
	_board = FabricatingBoard.new(size, size)
	_view = FabricatingGridView.new()
	_view.configure(_board, _CELL_SIZE)
	_canvas.set_board(_view, _view.content_size())
	# The canvas feeds pointer events to the view from its _gui_input.
	_canvas.input_handler = _on_board_input

# A square grid sized to the recipe's total footprint area plus packing slack.
func _board_size_for_recipe() -> int:
	var area: int = 0
	for kind: int in _KIND_COUNT:
		area += _remaining[kind] * _footprint_for(kind).size()
	return maxi(4, ceili(sqrt(float(area))) + 2)

func _footprint_for(kind: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _FOOTPRINTS[kind]:
		result.append(cell)
	return result

#endregion

#region Input

func _on_board_input(event: InputEvent) -> bool:
	if _view == null:
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index >= 1:
			if touch.pressed:
				_rotate_held()
			return true
		return _board_press(_view.cell_at(touch.position)) if touch.pressed else _board_release(_view.cell_at(touch.position))
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != 0:
			return false
		return _board_move(_view.cell_at(drag.position))
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			if mouse.pressed:
				_rotate_held()
			return true
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return false
		return _board_press(_view.cell_at(mouse.position)) if mouse.pressed else _board_release(_view.cell_at(mouse.position))
	if event is InputEventMouseMotion:
		return _board_move(_view.cell_at((event as InputEventMouseMotion).position))
	return false

func _board_press(cell: Vector2i) -> bool:
	if not _board.cell_exists(cell):
		return false
	if _held_kind >= 0:
		_positioning = true
		_hover(cell)
		return true
	# Nothing held: pull the piece under the cell back into the tray.
	var index := _board.index_at(cell)
	if index >= 0:
		_pull_piece(index)
	return true

func _board_move(cell: Vector2i) -> bool:
	if _held_kind < 0:
		return false
	_hover(cell)
	return true

func _board_release(cell: Vector2i) -> bool:
	if _held_kind >= 0 and _positioning and _board.cell_exists(cell):
		_try_place(cell)
	_positioning = false
	return true

func _hover(cell: Vector2i) -> void:
	_hovered_cell = cell
	if _held_kind < 0:
		return
	var footprint := _footprint_for(_held_kind)
	_view.set_preview(
		GridGeometry.occupied_cells(footprint, cell, _held_rotation),
		_board.can_place(footprint, cell, _held_rotation))

func _try_place(cell: Vector2i) -> void:
	var footprint := _footprint_for(_held_kind)
	if not _board.can_place(footprint, cell, _held_rotation):
		return
	_board.place(_COMPONENTS[_held_kind], footprint, cell, _held_rotation)
	_remaining[_held_kind] -= 1
	_cancel_hold()
	_rebuild_tray()
	_after_change()

func _pull_piece(index: int) -> void:
	var piece := _board.remove_at_index(index)
	var kind := _COMPONENTS.find(piece)
	if kind >= 0:
		_remaining[kind] += 1
	_rebuild_tray()
	_after_change()

func _rotate_held() -> void:
	if _held_kind < 0:
		return
	_held_rotation = (_held_rotation + 1) % 4
	_hover(_hovered_cell)

func _on_component_picked(kind: int) -> void:
	if kind < 0 or kind >= _remaining.size() or _remaining[kind] <= 0:
		return
	_held_kind = kind
	_held_rotation = 0
	if _tray != null:
		_tray.set_selected(kind)
	_show_play_status()

func _cancel_hold() -> void:
	_held_kind = -1
	_held_rotation = 0
	_positioning = false
	if _view != null:
		_view.clear_preview()
	if _tray != null:
		_tray.set_selected(-1)

func _after_change() -> void:
	inventory_changed.emit()
	if not _complete and _is_recipe_complete():
		_on_recipe_complete()
	else:
		_show_play_status()

func _rebuild_tray() -> void:
	if _tray == null:
		return
	var entries: Array[ComponentTray.Entry] = []
	if _selected_recipe != null:
		for kind: int in _KIND_COUNT:
			if _selected_recipe.requirements[kind] > 0:
				entries.append(ComponentTray.Entry.new(
					kind, _COMPONENTS[kind].color, _COMPONENTS[kind].name, _remaining[kind]))
	_tray.set_entries(entries)

#endregion

func _on_reset_pressed() -> void:
	if _selected_recipe == null:
		_show_selection()
		return
	_remaining = _selected_recipe.requirements.duplicate()
	_complete = false
	_cancel_hold()
	_build_board()
	_rebuild_tray()
	_show_play_status()
	inventory_changed.emit()

func _compose_status() -> void:
	status_text = _message

func _show_play_status() -> void:
	if _held_kind >= 0:
		_message = "Placing %s — drag on the grid, right-click / two-finger tap to rotate, lift to set." % _COMPONENTS[_held_kind].name
	else:
		_message = "Pack the recipe's components — %d left. Tap one below to pick it up." % _total_remaining()
	_compose_status()

#region Selection UI

func _build_selection_overlay() -> void:
	_selection_overlay = Control.new()
	_selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_selection_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.08, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_overlay.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)

	_selection_title = Label.new()
	_selection_title.text = "Select a Recipe"
	_selection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_title.add_theme_font_size_override("font_size", 40)
	column.add_child(_selection_title)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 20)
	column.add_child(cards)
	for recipe: _Recipe in _recipes:
		cards.add_child(_build_recipe_card(recipe))

func _build_recipe_card(recipe: _Recipe) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(220, 240)
	card.pressed.connect(_on_recipe_chosen.bind(recipe))

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var icon := ItemFootprintIcon.new()
	icon.blueprint = recipe.module
	icon.custom_minimum_size = _CARD_ICON_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)

	var name_label := Label.new()
	name_label.text = recipe.module.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var needs := HBoxContainer.new()
	needs.alignment = BoxContainer.ALIGNMENT_CENTER
	needs.add_theme_constant_override("separation", 10)
	needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for kind: int in _KIND_COUNT:
		if recipe.requirements[kind] <= 0:
			continue
		needs.add_child(_build_requirement_chip(kind, recipe.requirements[kind]))
	content.add_child(needs)
	return card

# A small swatch-and-count for one component a recipe needs.
func _build_requirement_chip(kind: int, count: int) -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := ColorRect.new()
	swatch.color = _COMPONENTS[kind].color
	swatch.custom_minimum_size = Vector2(20, 20)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(swatch)
	var label := Label.new()
	label.text = "×%d" % count
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip

func _show_selection() -> void:
	if _selection_overlay == null:
		return
	_selection_title.text = (
		"Fabricated! Select Another Recipe" if _complete else "Select a Recipe"
	)
	_selection_overlay.visible = true

#endregion

## One selectable recipe: the module it fabricates (drawn by its footprint) and how many of each
## component kind the player must pack to complete it.
class _Recipe:
	var module: ItemBlueprint
	var requirements: Array[int]

	func _init(recipe_module: ItemBlueprint, per_kind_requirements: Array[int]) -> void:
		module = recipe_module
		requirements = per_kind_requirements
