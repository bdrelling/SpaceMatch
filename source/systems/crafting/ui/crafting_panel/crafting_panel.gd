class_name CraftingPanel
extends OverlayPanel
## A crafting station's selection panel: lists the active [CraftingStation]'s recipes, one
## [RecipeButton] each, greying out those the player can't afford. Clicking one queues it (see
## [method CraftingStation.craft]); while the station works, every button greys out and the
## active recipe's button fills with craft progress. Stations that allow it (see
## [member CraftingStation.allows_craft_all]) also get an "All" button per recipe and one for the
## whole book. The list rebuilds as the inventory changes. Closes on ui_cancel.
##
## Driven entirely by [method open_for] — the station and player are injected, never looked up.
## Hosted by a [CraftingStationUI] in the level's overlay layer (above the HUD). Everything here is
## data-driven off the station, so most stations share one panel; a station that needs a bespoke UI
## points its [member CraftingStation.panel_scene] at a scene whose root extends this.

const SCENE_PATH := "res://systems/crafting/ui/crafting_panel/crafting_panel.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

@onready var _title: Label = %Title
@onready var _grid: GridContainer = %Grid

var _station: CraftingStation
var _player: Player
var _recipe_buttons: Dictionary[Recipe, RecipeButton] = {}

## Points the panel at [param station] + [param player], titles it, and shows it — (re)wiring the
## inventory and station listeners so the list tracks pickups/spends and craft progress while open.
func open_for(station: CraftingStation, player: Player) -> void:
	_bind_inventory(player)
	_bind_station(station)
	_station = station
	_player = player
	if _title != null:
		_title.text = _action_title()
	_rebuild()
	open()
	_focus_button(0)

## True while the panel is open and pointed at [param station] — lets the host close only the panel
## showing the station the player left, not whatever is currently up.
func is_showing(station: CraftingStation) -> bool:
	return is_open and _station == station

# Follows the active player's inventory so the list stays live; a no-op when it's already bound.
func _bind_inventory(player: Player) -> void:
	if _player == player:
		return
	if _player != null and _player.inventory.changed.is_connected(_on_inventory_changed):
		_player.inventory.changed.disconnect(_on_inventory_changed)
	if player != null and not player.inventory.changed.is_connected(_on_inventory_changed):
		player.inventory.changed.connect(_on_inventory_changed)

# Follows the active station's queue so buttons grey out and fill while it works; a no-op when
# it's already bound.
func _bind_station(station: CraftingStation) -> void:
	if _station == station:
		return
	if _station != null:
		_station.craft_started.disconnect(_on_station_craft_started)
		_station.craft_progressed.disconnect(_on_station_craft_progressed)
		_station.work_finished.disconnect(_on_station_work_finished)
	if station != null:
		station.craft_started.connect(_on_station_craft_started)
		station.craft_progressed.connect(_on_station_craft_progressed)
		station.work_finished.connect(_on_station_work_finished)

func _on_inventory_changed(_inventory: Inventory) -> void:
	_refresh()

func _on_station_craft_started(_recipe: Recipe) -> void:
	_refresh()

func _on_station_craft_progressed(recipe: Recipe, progress: float) -> void:
	var button: RecipeButton = _recipe_buttons.get(recipe)
	if button != null:
		button.progress = progress

func _on_station_work_finished() -> void:
	_refresh()

# Rebuilds the list in place, keeping focus on the same slot so navigation survives the swap.
func _refresh() -> void:
	var focused := _focused_index()
	_rebuild()
	if is_open:
		_focus_button(maxi(focused, 0))

func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_recipe_buttons.clear()

	if _station == null or _station.recipe_book == null or _player == null:
		return

	var busy := _station.is_working
	var any_affordable := false
	for recipe: Recipe in _station.recipe_book.all_recipes():
		if recipe == null:
			continue
		var affordable := recipe.can_craft(_player.inventory)
		any_affordable = any_affordable or affordable
		var button := RecipeButton.create(recipe.name)
		button.disabled = busy or not affordable
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: _station.craft(_player.inventory, recipe))
		_recipe_buttons[recipe] = button
		_grid.add_child(_as_row(button, recipe, busy, affordable))

	if _station.allows_craft_all:
		var craft_all_button := Button.new()
		craft_all_button.text = "%s All" % _action_title()
		craft_all_button.disabled = busy or not any_affordable
		craft_all_button.pressed.connect(func() -> void: _station.craft_all(_player.inventory))
		_grid.add_child(craft_all_button)

# A grid row for [param button]: the button itself normally, or paired with a per-recipe "All"
# button when the station allows craft-all.
func _as_row(button: RecipeButton, recipe: Recipe, busy: bool, affordable: bool) -> Control:
	if not _station.allows_craft_all:
		return button
	var row := HBoxContainer.new()
	row.add_child(button)
	var all_button := Button.new()
	all_button.text = "All"
	all_button.disabled = busy or not affordable
	all_button.pressed.connect(func() -> void: _station.craft_all(_player.inventory, recipe))
	row.add_child(all_button)
	return row

func _action_title() -> String:
	return _station.action_label if not _station.action_label.is_empty() else String(_station.name)

# Focuses the recipe button at [param index] (clamped) so keyboard/gamepad navigation has a
# target — without a focused Control, ui_accept has nowhere to route and the panel is mouse-only.
func _focus_button(index: int) -> void:
	var buttons := _buttons()
	if buttons.is_empty():
		return
	buttons[clampi(index, 0, buttons.size() - 1)].grab_focus.call_deferred()

# Index of the grid button that currently holds focus, or -1 when focus is elsewhere.
func _focused_index() -> int:
	return _buttons().find(get_viewport().gui_get_focus_owner())

# The grid's current buttons in display order — including those nested in craft-all rows —
# skipping any still pending deletion from a rebuild.
func _buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in _grid.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Button:
			buttons.append(child)
			continue
		for nested in child.get_children():
			if nested is Button and not nested.is_queued_for_deletion():
				buttons.append(nested)
	return buttons

func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputAction.INTERACT):
		# The button that opened the panel also picks from it. Read directly — this panel claims
		# BLOCK_ALL while open, which silences its own actions through [ManagedInput] (the
		# documented pairing in [member OverlayPanel.input_policy]). Consumed even when nothing
		# is focused so the press never reaches the [Player] and re-interacts with the station.
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and _buttons().has(focused) and not focused.disabled:
			focused.pressed.emit()
		get_viewport().set_input_as_handled()

static func create() -> CraftingPanel:
	return SCENE.instantiate()
