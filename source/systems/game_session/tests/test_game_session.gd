extends GdUnitTestSuite
## The game-session spine: a fresh game seeds one player, binding an inventory node shares that
## player's [InventoryState] in place (mutations land on the save, not a copy), an already-loaded
## player keeps its contents on bind, and a populated [GameState] round-trips through serialization.

func _blueprint(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func test_new_game_seeds_one_empty_player() -> void:
	var session := GameSession.new_game()
	assert_int(session.state.players.size()).is_equal(1)
	assert_int(session.player(0).inventory.stacks.size()).is_equal(0)
	assert_int(session.player(0).currency).is_equal(0)

func test_bind_shares_inventory_state_with_player() -> void:
	var session := GameSession.new_game()
	var inventory := Inventory.new()
	add_child(inventory)
	session.bind_inventory(inventory, 0)
	var no_tags: Array[Item.Tag] = []
	inventory.add_variant(_blueprint(1), no_tags, 3)
	# The mutation landed on the player's own state, not a private node copy.
	assert_int(session.player(0).inventory.stacks.size()).is_equal(1)
	assert_int(session.player(0).inventory.stacks[0].quantity).is_equal(3)
	inventory.queue_free()

func test_bind_preserves_a_loaded_players_contents() -> void:
	var session := GameSession.new_game()
	session.player(0).inventory.stacks.append(ItemStack.create(_blueprint(2), 4))
	var inventory := Inventory.new()
	add_child(inventory)
	session.bind_inventory(inventory, 0)
	# A non-empty (loaded) state survives bind — the node adopts it as-is, the save wins.
	assert_int(inventory.count(2)).is_equal(4)
	inventory.queue_free()

func test_game_state_round_trips_through_serialization() -> void:
	var session := GameSession.new_game()
	session.player(0).currency = 42
	session.player(0).inventory.stacks.append(ItemStack.create(_blueprint(7), 5))
	var bytes := var_to_bytes_with_objects(session.state)
	var restored: GameState = bytes_to_var_with_objects(bytes)
	assert_int(restored.players.size()).is_equal(1)
	assert_int(restored.players[0].currency).is_equal(42)
	assert_int(restored.players[0].inventory.stacks.size()).is_equal(1)
	assert_int(restored.players[0].inventory.stacks[0].quantity).is_equal(5)

func test_arcade_state_carries_salvaging() -> void:
	var session := GameSession.new_game()
	session.state.arcade = ArcadeState.new()
	var salvaging := SalvagingState.new()
	salvaging.width = 2
	salvaging.height = 1
	salvaging.object_count = 1
	salvaging.objects = PackedByteArray([1, 0])
	salvaging.revealed = PackedByteArray([0, 1])
	salvaging.adjacent = PackedInt32Array([0, 1])
	salvaging.actions_used = 5
	session.state.arcade.salvaging = salvaging
	var bytes := var_to_bytes_with_objects(session.state)
	var restored: GameState = bytes_to_var_with_objects(bytes)
	assert_bool(restored.arcade.salvaging.has_field()).is_true()
	assert_int(restored.arcade.salvaging.actions_used).is_equal(5)
	assert_int(restored.arcade.salvaging.objects[0]).is_equal(1)
	assert_int(restored.arcade.salvaging.revealed[1]).is_equal(1)

func test_crafting_station_absent_returns_null() -> void:
	var session := GameSession.new_game()
	assert_object(session.crafting_station(&"assembler")).is_null()

func test_add_and_find_crafting_station_by_id() -> void:
	var session := GameSession.new_game()
	var station := CraftingStationState.new(&"assembler")
	session.add_crafting_station(station)
	assert_bool(session.crafting_station(&"assembler") == station).is_true()

func test_add_crafting_station_ignores_duplicate_id() -> void:
	var session := GameSession.new_game()
	session.add_crafting_station(CraftingStationState.new(&"assembler"))
	session.add_crafting_station(CraftingStationState.new(&"assembler"))
	assert_int(session.state.outpost.crafting_stations.size()).is_equal(1)

func test_crafting_station_round_trips_with_inventory() -> void:
	var session := GameSession.new_game()
	var station := CraftingStationState.new(&"assembler")
	station.inventory = InventoryState.new()
	station.inventory.stacks.append(ItemStack.create(_blueprint(9), 6))
	session.add_crafting_station(station)
	var bytes := var_to_bytes_with_objects(session.state)
	var restored: GameState = bytes_to_var_with_objects(bytes)
	assert_int(restored.outpost.crafting_stations.size()).is_equal(1)
	var loaded := restored.outpost.crafting_stations[0]
	assert_str(String(loaded.id)).is_equal("assembler")
	assert_int(loaded.inventory.stacks[0].quantity).is_equal(6)
