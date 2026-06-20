extends GdUnitTestSuite
## Tests the Chest structure and its storage panel — the authored grid inventory, the
## interact-driven open/close flow, and whole-stack click transfers in both directions.

func _blueprint(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func _item_of(blueprint: ItemBlueprint) -> Item:
	var item: Item = auto_free(Item.new())
	item.apply_blueprint(blueprint)
	return item

func _chest() -> Chest:
	var chest: Chest = auto_free(Chest.create())
	add_child(chest)
	return chest

func _grid_inventory(width: int, height: int) -> Inventory:
	var rule := GridCapacityRule.new()
	rule.width = width
	rule.height = height
	var inventory: Inventory = auto_free(Inventory.new())
	inventory.capacity_rule = rule
	return inventory

# A detached Player (never in the tree, so no scene dependencies) with a grid inventory,
# enough for the panel's signal and transfer paths.
func _player() -> Player:
	var player: Player = auto_free(Player.new())
	player.inventory = _grid_inventory(8, 5)
	return player

func _panel(player: Player) -> ChestGridInventoryPanel:
	var panel: ChestGridInventoryPanel = auto_free(ChestGridInventoryPanel.create(player))
	add_child(panel)
	return panel

func test_chest_authors_grid_inventory() -> void:
	var chest := _chest()
	await await_idle_frame()
	assert_object(chest.inventory).is_not_null()
	var rule := chest.inventory.capacity_rule as GridCapacityRule
	assert_object(rule).is_not_null()
	assert_int(rule.width).is_equal(6)
	assert_int(rule.height).is_equal(3)
	assert_int(rule.single_cell_rows).is_equal(0)

func test_interact_emits_interacted() -> void:
	var chest := _chest()
	await await_idle_frame()
	var emitted: Array[bool] = [false]
	chest.interacted.connect(func() -> void: emitted[0] = true)
	chest.interact(_player())
	assert_bool(emitted[0]).is_true()

func test_panel_opens_and_closes_via_interaction_signals() -> void:
	var chest := _chest()
	var panel := _panel(_player())
	await await_idle_frame()
	panel._on_structure_interacted(chest)
	assert_bool(panel.is_open).is_true()
	assert_object(panel.inventory).is_same(chest.inventory)
	# A second interact with the same chest toggles it closed.
	panel._on_structure_interacted(chest)
	assert_bool(panel.is_open).is_false()
	# Walking away closes it too.
	panel._on_structure_interacted(chest)
	panel._on_structure_exited(chest)
	assert_bool(panel.is_open).is_false()

func test_click_transfers_whole_stack_both_ways() -> void:
	var chest := _chest()
	var player := _player()
	var panel := _panel(player)
	await await_idle_frame()
	chest.inventory.add(_item_of(_blueprint(1)), 3)
	player.inventory.add(_item_of(_blueprint(2)), 2)
	panel._on_structure_interacted(chest)
	# Chest grid click: the stack lands whole in the player's inventory.
	var chest_anchor := chest.inventory.get_placements()[0].anchor
	panel._on_cell_pressed(chest_anchor)
	assert_int(chest.inventory.count(1)).is_equal(0)
	assert_int(player.inventory.count(1)).is_equal(3)
	# Player grid click: the stack lands whole in the chest.
	var player_anchor := player.inventory.placement_of(player.inventory.get_stacks()[0]).anchor
	panel._on_player_cell_pressed(player_anchor)
	assert_int(player.inventory.count(2)).is_equal(0)
	assert_int(chest.inventory.count(2)).is_equal(2)
