extends GdUnitTestSuite
## The game-session spine: a fresh game starts with a default starship, and a populated [GameState]
## round-trips through serialization.

func test_new_game_starts_with_a_default_starship() -> void:
	GameSession.start_new_game()
	assert_object(GameSession.game_state.starship).is_not_null()

func test_game_state_round_trips_through_serialization() -> void:
	GameSession.start_new_game()
	GameSession.game_state.starship.name = "Wanderer"
	var bytes := var_to_bytes_with_objects(GameSession.game_state)
	var restored: GameState = bytes_to_var_with_objects(bytes)
	assert_str(restored.starship.name).is_equal("Wanderer")
