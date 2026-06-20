extends GdUnitTestSuite
## Tests the inventory shelf UI — InventoryGridView tile building, GridInventoryPanel
## pick-up/place flow, the closed quickbar strip, and slot selection.

func _blueprint(id: int, footprint_cells: Array[Vector2i] = [Vector2i.ZERO]) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	blueprint.color = Color.RED
	blueprint.footprint_cells = footprint_cells
	return blueprint

func _item_of(blueprint: ItemBlueprint) -> Item:
	var item: Item = auto_free(Item.new())
	item.apply_blueprint(blueprint)
	return item

func _grid_inventory(width: int, height: int) -> Inventory:
	var rule := GridCapacityRule.new()
	rule.width = width
	rule.height = height
	var inventory: Inventory = auto_free(Inventory.new())
	inventory.capacity_rule = rule
	return inventory

func _panel() -> PlayerGridInventoryPanel:
	var panel: PlayerGridInventoryPanel = auto_free(PlayerGridInventoryPanel.create())
	add_child(panel)
	return panel

func _live_tiles(panel: GridInventoryPanel) -> Array[InventoryStackTile]:
	var view: InventoryGridView = panel.get_node("%View")
	var tiles: Array[InventoryStackTile] = []
	for child in view.get_node("%Tiles").get_children():
		if not child.is_queued_for_deletion():
			tiles.append(child)
	return tiles

func test_register_builds_one_tile_per_stack() -> void:
	var panel := _panel()
	await await_idle_frame()
	var inventory := _grid_inventory(3, 3)
	inventory.add(_item_of(_blueprint(1)))
	inventory.add(_item_of(_blueprint(2)))
	panel.register(inventory)
	await await_idle_frame()
	assert_int(_live_tiles(panel).size()).is_equal(2)

func test_multi_cell_stack_renders_single_spanning_tile() -> void:
	var domino: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var panel := _panel()
	await await_idle_frame()
	var inventory := _grid_inventory(3, 3)
	inventory.add(_item_of(_blueprint(1, domino)))
	panel.register(inventory)
	await await_idle_frame()
	var tiles := _live_tiles(panel)
	assert_int(tiles.size()).is_equal(1)
	# Two 48px cells plus the 4px gutter between them.
	assert_float(tiles[0].size.x).is_equal(100.0)

func test_cell_press_picks_up_then_places() -> void:
	var panel := _panel()
	await await_idle_frame()
	var inventory := _grid_inventory(3, 3)
	inventory.add(_item_of(_blueprint(1)))
	panel.register(inventory)
	var stack := inventory.get_stacks()[0]
	panel._on_cell_pressed(Vector2i(0, 0))
	panel._on_cell_pressed(Vector2i(2, 2))
	assert_that(inventory.placement_of(stack).anchor).is_equal(Vector2i(2, 2))

func test_rebuilds_when_inventory_changes() -> void:
	var panel := _panel()
	await await_idle_frame()
	var inventory := _grid_inventory(3, 3)
	inventory.add(_item_of(_blueprint(1)))
	panel.register(inventory)
	await await_idle_frame()
	assert_int(_live_tiles(panel).size()).is_equal(1)
	inventory.add(_item_of(_blueprint(2)))
	await await_idle_frame()
	await await_idle_frame()
	assert_int(_live_tiles(panel).size()).is_equal(2)

func test_panel_scene_configuration() -> void:
	var panel := _panel()
	await await_idle_frame()
	assert_str(panel.toggle_action).is_equal(&"toggle_inventory")
	assert_int(panel.input_policy).is_equal(OverlayPanel.InputPolicy.BLOCK_ALL)

func test_closed_shelf_keeps_quickbar_strip_visible() -> void:
	var panel := _panel()
	await await_idle_frame()
	panel.register(_grid_inventory(4, 2))
	await await_idle_frame()
	var box: PanelContainer = panel.get_node("%Box")
	# Content never hides; the chrome is faded out and the box is slid down instead.
	assert_bool(panel.content.visible).is_true()
	assert_float(box.self_modulate.a).is_equal(0.0)
	var closed_y := box.position.y
	panel._set_openness(1.0)
	assert_float(box.self_modulate.a).is_equal(1.0)
	assert_float(box.position.y).is_less(closed_y)

func test_selected_slot_clamps_to_grid_width() -> void:
	var panel := _panel()
	await await_idle_frame()
	panel.register(_grid_inventory(4, 2))
	panel.selected_slot = 99
	assert_int(panel.selected_slot).is_equal(3)

func test_standalone_quickbar_shows_only_grid_inventories() -> void:
	var quickbar: InventoryQuickbar = auto_free(InventoryQuickbar.create())
	add_child(quickbar)
	await await_idle_frame()
	var unruled: Inventory = auto_free(Inventory.new())
	quickbar.register(unruled)
	assert_bool(quickbar.visible).is_false()
	quickbar.register(_grid_inventory(4, 2))
	assert_bool(quickbar.visible).is_true()
	quickbar.set_suppressed(true)
	assert_bool(quickbar.visible).is_false()
	quickbar.selected_slot = 99
	assert_int(quickbar.selected_slot).is_equal(3)

func test_section_gap_offsets_rows_below_single_cell_rows() -> void:
	var domino: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var panel := _panel()
	await await_idle_frame()
	var view: InventoryGridView = panel.get_node("%View")
	var inventory := _grid_inventory(3, 3)
	(inventory.capacity_rule as GridCapacityRule).single_cell_rows = 1
	inventory.add(_item_of(_blueprint(1)))
	inventory.add(_item_of(_blueprint(2, domino)))
	panel.register(inventory)
	await await_idle_frame()
	var pitch := view.cell_size + view.cell_separation
	for tile: InventoryStackTile in _live_tiles(panel):
		if tile.stack.item_blueprint.id == 1:
			assert_float(tile.position.y).is_equal(0.0)
		else:
			# Auto-placed into row 1, pushed down by the section gap.
			assert_float(tile.position.y).is_equal(float(pitch + view.section_separation))
