extends GdUnitTestSuite
## Covers the crafting panel's in-panel input — while open, interact crafts the focused recipe
## button, skips disabled ones, and is always consumed so the press never leaks to the [Player] —
## and its queue states: buttons grey out while the station works, the active button fills with
## craft progress, and craft-all buttons appear only when the station allows them.

const _STRUCTURE_SCENE: PackedScene = preload("res://systems/world/structure/structure.tscn")
const _INPUT_ID := 1

var _world: Node3D
var _station: CraftingStation
var _player: Player

func before_test() -> void:
	# Station + player built here (out-of-tree nodes created mid-test read as orphans); each
	# test stocks and opens via _open_panel_for_station.
	var structure: Node3D = _STRUCTURE_SCENE.instantiate()
	structure.set_script(CraftingStation)
	_station = structure as CraftingStation
	_station.action_label = "Recycle"
	_world = Node3D.new()
	add_child(_world)
	_world.add_child(_station)
	_player = Player.SCENE.instantiate()
	_player.inventory = Inventory.create(InventoryBlueprint.new())
	_player.add_child(_player.inventory)

func after_test() -> void:
	_world.free()
	_player.free()

func _panel() -> CraftingPanel:
	var panel: CraftingPanel = auto_free(CraftingPanel.create())
	add_child(panel)
	return panel

func _item_blueprint(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func _test_book() -> RecipeBook:
	var recipe_blueprint := RecipeBlueprint.new()
	recipe_blueprint.inputs.append(ItemStack.create(_item_blueprint(_INPUT_ID)))
	recipe_blueprint.outputs.append(ItemStack.create(_item_blueprint(2)))
	recipe_blueprint.name = "Test Craft"
	var book_blueprint := RecipeBookBlueprint.new()
	book_blueprint.recipes.append(recipe_blueprint)
	return RecipeBook.create(book_blueprint)

# A panel opened on a one-recipe station whose player holds [param stock] of the input item.
func _open_panel_for_station(stock: int, allows_craft_all := false) -> CraftingPanel:
	_station.allows_craft_all = allows_craft_all
	_station.recipe_book = _test_book()
	var inventory_blueprint := InventoryBlueprint.new()
	if stock > 0:
		inventory_blueprint.item_stacks.append(ItemStack.create(_item_blueprint(_INPUT_ID), stock))
	_player.inventory.apply_blueprint(inventory_blueprint)
	var panel := _panel()
	panel.open_for(_station, _player)
	return panel

func _interact_press() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = InputAction.INTERACT
	event.pressed = true
	return event

# Adds a recipe-style button to the panel's grid, counting presses into [param presses][0]
# (an array because lambdas capture ints by value).
func _add_button(panel: CraftingPanel, presses: Array[int]) -> Button:
	var button := Button.new()
	button.pressed.connect(func() -> void: presses[0] += 1)
	panel._grid.add_child(button)
	return button

func test_interact_crafts_focused_recipe() -> void:
	var panel := _panel()
	await await_idle_frame()
	var presses: Array[int] = [0]
	var button := _add_button(panel, presses)
	panel.open()
	await await_idle_frame()
	button.grab_focus()
	panel._unhandled_input(_interact_press())
	assert_int(presses[0]).is_equal(1)

func test_interact_skips_disabled_recipe() -> void:
	var panel := _panel()
	await await_idle_frame()
	var presses: Array[int] = [0]
	var button := _add_button(panel, presses)
	button.disabled = true
	panel.open()
	await await_idle_frame()
	button.grab_focus()
	panel._unhandled_input(_interact_press())
	assert_int(presses[0]).is_equal(0)

func test_interact_ignored_while_closed() -> void:
	var panel := _panel()
	await await_idle_frame()
	var presses: Array[int] = [0]
	var button := _add_button(panel, presses)
	panel._unhandled_input(_interact_press())
	assert_int(presses[0]).is_equal(0)
	assert_bool(button.has_focus()).is_false()

func test_buttons_grey_out_while_working() -> void:
	var panel := _open_panel_for_station(2)
	await await_idle_frame()
	assert_bool(panel._buttons()[0].disabled).is_false()
	_station.craft(_player.inventory, _station.recipe_book.all_recipes()[0])
	for button in panel._buttons():
		assert_bool(button.disabled).is_true()

func test_active_button_fills_with_progress() -> void:
	var panel := _open_panel_for_station(1)
	await await_idle_frame()
	var recipe: Recipe = _station.recipe_book.all_recipes()[0]
	_station.craft(_player.inventory, recipe)
	_station._advance(0.175)
	var button: RecipeButton = panel._recipe_buttons[recipe]
	assert_float(button.progress).is_equal_approx(0.5, 0.01)

func test_work_finished_reenables_buttons() -> void:
	var panel := _open_panel_for_station(2)
	await await_idle_frame()
	_station.craft(_player.inventory, _station.recipe_book.all_recipes()[0])
	_station._advance(0.35)
	assert_bool(_station.is_working).is_false()
	assert_bool(panel._buttons()[0].disabled).is_false()

func test_craft_all_buttons_offered_when_allowed() -> void:
	var panel := _open_panel_for_station(2, true)
	await await_idle_frame()
	var buttons := panel._buttons()
	assert_int(buttons.size()).is_equal(3)
	assert_str(buttons[1].text).is_equal("All")
	assert_str(buttons[2].text).is_equal("Recycle All")
	buttons[2].pressed.emit()
	assert_bool(_station.is_working).is_true()

func test_craft_all_buttons_hidden_by_default() -> void:
	var panel := _open_panel_for_station(2)
	await await_idle_frame()
	assert_int(panel._buttons().size()).is_equal(1)
