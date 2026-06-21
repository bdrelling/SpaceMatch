extends GdUnitTestSuite
## The game-session spine: a fresh game starts with an empty inventory, binding an inventory node
## shares the game's [InventoryState] in place (mutations land on the save, not a copy), an already
## loaded state keeps its contents on bind, and a populated [GameState] round-trips through
## serialization.

func _blueprint(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func test_new_game_starts_with_an_empty_inventory() -> void:
	var session := GameSession.new_game()
	assert_int(session.state.inventory.stacks.size()).is_equal(0)

func test_bind_shares_inventory_state_in_place() -> void:
	var session := GameSession.new_game()
	var inventory := Inventory.new()
	add_child(inventory)
	session.bind_inventory(inventory)
	var no_tags: Array[Item.Tag] = []
	inventory.add_variant(_blueprint(1), no_tags, 3)
	# The mutation landed on the game's own state, not a private node copy.
	assert_int(session.state.inventory.stacks.size()).is_equal(1)
	assert_int(session.state.inventory.stacks[0].quantity).is_equal(3)
	inventory.queue_free()

func test_bind_preserves_loaded_contents() -> void:
	var session := GameSession.new_game()
	session.state.inventory.stacks.append(ItemStack.create(_blueprint(2), 4))
	var inventory := Inventory.new()
	add_child(inventory)
	session.bind_inventory(inventory)
	# A non-empty (loaded) state survives bind — the node adopts it as-is, the save wins.
	assert_int(inventory.count(2)).is_equal(4)
	inventory.queue_free()

func test_game_state_round_trips_through_serialization() -> void:
	var session := GameSession.new_game()
	session.state.inventory.stacks.append(ItemStack.create(_blueprint(7), 5))
	var bytes := var_to_bytes_with_objects(session.state)
	var restored: GameState = bytes_to_var_with_objects(bytes)
	assert_int(restored.inventory.stacks.size()).is_equal(1)
	assert_int(restored.inventory.stacks[0].quantity).is_equal(5)
