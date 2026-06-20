extends GdUnitTestSuite
## Covers the craft queue: inputs are consumed when a craft begins and outputs eject when its
## duration elapses; craft-all orders repeat until the inventory runs dry (sweeping the whole
## book when no recipe is named); the instant-craft flag collapses the queue into one advance.

const _STRUCTURE_SCENE: PackedScene = preload("res://systems/world/structure/structure.tscn")
const _INPUT_ID := 1
const _OUTPUT_ID := 2

var _world: Node3D
var _station: CraftingStation
var _player: Player
var _crafted: Array[Recipe] = []
var _finishes: Array[int] = [0]

func before_test() -> void:
	# The base structure scene carries no script; attaching CraftingStation before entering the
	# tree gives a station with no game data attached — recipes and stock come from each test.
	var structure: Node3D = _STRUCTURE_SCENE.instantiate()
	structure.set_script(CraftingStation)
	_station = structure as CraftingStation
	_world = Node3D.new()
	add_child(_world)
	_world.add_child(_station)
	# Kept out of the tree (like test_player_collect.gd): the station only reads its inventory.
	_player = Player.SCENE.instantiate()
	_player.inventory = Inventory.create(InventoryBlueprint.new())
	_player.add_child(_player.inventory)
	_crafted = []
	_finishes = [0]
	_station.crafted.connect(func(recipe: Recipe) -> void: _crafted.append(recipe))
	_station.work_finished.connect(func() -> void: _finishes[0] += 1)

func after_test() -> void:
	_world.free()
	_player.free()

func _item(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func _recipe_blueprint(input_id: int, duration: float = 0.35) -> RecipeBlueprint:
	var blueprint := RecipeBlueprint.new()
	blueprint.duration = duration
	blueprint.inputs.append(ItemStack.create(_item(input_id)))
	blueprint.outputs.append(ItemStack.create(_item(_OUTPUT_ID)))
	blueprint.name = "Craft %d" % input_id
	return blueprint

func _recipe(duration: float = 0.35) -> Recipe:
	return Recipe.create(_recipe_blueprint(_INPUT_ID, duration))

func _book(recipe_blueprints: Array[RecipeBlueprint]) -> RecipeBook:
	var blueprint := RecipeBookBlueprint.new()
	blueprint.recipes = recipe_blueprints
	return RecipeBook.create(blueprint)

# Restocks the player's inventory to hold exactly [param stacks].
func _give(stacks: Array[ItemStack]) -> void:
	var blueprint := InventoryBlueprint.new()
	blueprint.item_stacks = stacks
	_player.inventory.apply_blueprint(blueprint)

func _stock(quantity: int) -> void:
	var stacks: Array[ItemStack] = []
	if quantity > 0:
		stacks.append(ItemStack.create(_item(_INPUT_ID), quantity))
	_give(stacks)

func test_craft_consumes_inputs_up_front() -> void:
	_stock(2)
	assert_bool(_station.craft(_player.inventory, _recipe())).is_true()
	assert_int(_player.inventory.count(_INPUT_ID)).is_equal(1)
	assert_bool(_station.is_working).is_true()
	assert_array(_crafted).is_empty()

func test_craft_completes_after_duration() -> void:
	_stock(1)
	var recipe := _recipe(0.35)
	_station.craft(_player.inventory, recipe)
	_station._advance(0.2)
	assert_array(_crafted).is_empty()
	_station._advance(0.2)
	assert_array(_crafted).contains_exactly([recipe])
	assert_bool(_station.is_working).is_false()
	assert_int(_finishes[0]).is_equal(1)

func test_progress_reported_mid_craft() -> void:
	_stock(1)
	var progress: Array[float] = []
	_station.craft_progressed.connect(func(_recipe: Recipe, value: float) -> void: progress.append(value))
	_station.craft(_player.inventory, _recipe(1.0))
	_station._advance(0.5)
	assert_float(progress.back()).is_equal_approx(0.5, 0.001)

func test_outputs_eject_as_items() -> void:
	_stock(1)
	_station.craft(_player.inventory, _recipe())
	_station._advance(0.35)
	var items := 0
	for child in _world.get_children():
		if child is Item:
			items += 1
	assert_int(items).is_equal(1)

func test_rejects_unaffordable_craft() -> void:
	_stock(0)
	assert_bool(_station.craft(_player.inventory, _recipe())).is_false()
	assert_bool(_station.is_working).is_false()

func test_craft_all_repeats_until_inventory_dry() -> void:
	_stock(3)
	assert_bool(_station.craft_all(_player.inventory, _recipe())).is_true()
	# Padded past 3 × 0.35: accumulated float error would leave the third craft a hair short.
	_station._advance(3 * 0.35 + 0.001)
	assert_int(_crafted.size()).is_equal(3)
	assert_int(_player.inventory.count(_INPUT_ID)).is_equal(0)
	assert_bool(_station.is_working).is_false()
	assert_int(_finishes[0]).is_equal(1)

func test_craft_all_sweeps_whole_book() -> void:
	var second_input := 3
	_station.recipe_book = _book([_recipe_blueprint(_INPUT_ID), _recipe_blueprint(second_input)])
	_give([ItemStack.create(_item(_INPUT_ID)), ItemStack.create(_item(second_input))])
	assert_bool(_station.craft_all(_player.inventory)).is_true()
	_station._advance(1.0)
	assert_int(_crafted.size()).is_equal(2)
	assert_bool(_station.is_working).is_false()

func test_craft_all_rejected_when_nothing_affordable() -> void:
	_stock(0)
	assert_bool(_station.craft_all(_player.inventory, _recipe())).is_false()
	assert_bool(_station.is_working).is_false()

func test_instant_flag_collapses_queue() -> void:
	var flag := FeatureFlag.new()
	flag.key = "test_instant_crafting"
	flag.default_value = true
	_station.instant_craft_flag = flag
	_stock(5)
	assert_bool(_station.craft_all(_player.inventory, _recipe())).is_true()
	assert_int(_crafted.size()).is_equal(5)
	assert_int(_player.inventory.count(_INPUT_ID)).is_equal(0)
	assert_bool(_station.is_working).is_false()
