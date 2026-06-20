extends GdUnitTestSuite
## Tests the read-only inventory UI — ItemStackView rendering and InventoryPanel's
## changed-driven rebuild (DC-131).

func _blueprint(id: int, name := "Item") -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = name
	blueprint.color = Color.RED
	blueprint.inventory_texture = PlaceholderTexture2D.new()
	return blueprint

func _item(id: int) -> Item:
	var item: Item = auto_free(Item.new())
	item.apply_blueprint(_blueprint(id))
	return item

func _inventory() -> Inventory:
	return auto_free(Inventory.new())

func _live_grid_count(panel: InventoryPanel) -> int:
	var grid := panel.get_node("%Grid") as GridContainer
	var count := 0
	for child in grid.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count

func test_item_stack_view_shows_quantity_and_icon() -> void:
	var blueprint := _blueprint(1)
	var view: ItemStackView = auto_free(ItemStackView.create(ItemStack.create(blueprint, 7)))
	add_child(view)
	await await_idle_frame()
	var icon := view.get_node("%Icon") as TextureRect
	var quantity := view.get_node("%Quantity") as Label
	assert_str(quantity.text).is_equal("7")
	assert_object(icon.texture).is_equal(blueprint.inventory_texture)
	assert_that(icon.modulate).is_equal(Color.RED)

func test_register_populates_grid_one_view_per_stack() -> void:
	var panel: InventoryPanel = auto_free(InventoryPanel.create())
	add_child(panel)
	await await_idle_frame()
	var inventory := _inventory()
	inventory.add(_item(1))
	inventory.add(_item(2))
	panel.register(inventory)
	await await_idle_frame()
	assert_int(_live_grid_count(panel)).is_equal(2)

func test_grid_rebuilds_when_inventory_changes() -> void:
	var panel: InventoryPanel = auto_free(InventoryPanel.create())
	add_child(panel)
	await await_idle_frame()
	var inventory := _inventory()
	inventory.add(_item(1))
	panel.register(inventory)
	await await_idle_frame()
	assert_int(_live_grid_count(panel)).is_equal(1)
	# A new distinct item flows through the changed signal into a new view.
	inventory.add(_item(2))
	await await_idle_frame()
	await await_idle_frame()
	assert_int(_live_grid_count(panel)).is_equal(2)

func test_panel_toggle_action_is_bound_to_inventory() -> void:
	var panel: InventoryPanel = auto_free(InventoryPanel.create())
	add_child(panel)
	await await_idle_frame()
	assert_str(panel.toggle_action).is_equal(&"toggle_inventory")
