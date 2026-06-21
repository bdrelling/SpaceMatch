extends GdUnitTestSuite
## The game-session spine: a fresh game starts with a default ship, and a populated [GameState]
## round-trips through serialization.

func test_new_game_starts_with_a_default_ship() -> void:
	var session := GameSession.new_game()
	assert_object(session.state.ship).is_not_null()

func test_game_state_round_trips_through_serialization() -> void:
	var session := GameSession.new_game()
	session.state.ship.name = "Wanderer"
	var bytes := var_to_bytes_with_objects(session.state)
	var restored: GameState = bytes_to_var_with_objects(bytes)
	assert_str(restored.ship.name).is_equal("Wanderer")
