extends GdUnitTestSuite
## GameCoordinator — the seam that builds the game's states and points the session at them. A fresh game seeds
## the default starship and wallet; a Quick Match opens an encounter (a clone of the running starship vs the
## computer default) on the session.

# A fresh default game backs each test; tests that need a different starting point reset the session themselves.
func before_test() -> void:
	GameSession.start_new_game()

# Seeding a new game gives the session a default starship and an empty wallet, and no encounter yet.
func test_start_new_game_seeds_defaults() -> void:
	GameSession.game_state = null
	GameCoordinator.start_new_game()
	assert_object(GameSession.game_state).is_not_null()
	assert_object(GameSession.game_state.starship).is_not_null()
	assert_object(GameSession.game_state.wallet).is_not_null()
	assert_object(GameSession.game_state.encounter).is_null()

# A Quick Match builds an encounter with both combatants and points the session at its state.
func test_start_quick_match_opens_an_encounter_on_the_session() -> void:
	var encounter: Encounter = auto_free(GameCoordinator.start_quick_match())
	assert_object(encounter.state).is_not_null()
	assert_object(encounter.state.player).is_not_null()
	assert_object(encounter.state.opponent).is_not_null()
	assert_object(GameSession.game_state.encounter).is_same(encounter.state)

# With no persistent starship on the session, a Quick Match still opens — the player falls back to the default.
func test_start_quick_match_falls_back_to_default_player() -> void:
	GameSession.game_state.starship = null
	var encounter: Encounter = auto_free(GameCoordinator.start_quick_match())
	assert_object(encounter.state.player).is_not_null()
