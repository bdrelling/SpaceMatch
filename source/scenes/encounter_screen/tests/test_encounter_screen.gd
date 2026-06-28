extends GdUnitTestSuite
## EncounterScreen — the screen that hosts the match and owns the encounter. These guard the screen-level
## wiring; the match's own behaviour is covered in minigames/match/tests/test_match.gd.

const SCENE := "res://scenes/encounter_screen/encounter_screen.tscn"

# Fresh default game (starship + wallet) before each test so runs don't leak the shared GameSession state.
func before_test() -> void:
	GameSession.start_new_game()

func _open_screen() -> EncounterScreen:
	var screen: EncounterScreen = auto_free(load(SCENE).instantiate())
	add_child(screen)
	return screen

# Restart from the Settings menu must rebind the match onto a fresh encounter and restart the board — not just
# reopen the encounter while the match keeps rendering the finished one. (The regression: _on_settings_restart
# reopened the encounter but never re-bound the match, so the menu closed and the board never reset.)
func test_settings_restart_rebinds_and_restarts_the_match() -> void:
	var screen := _open_screen()
	await await_idle_frame()
	var match_game: MatchMinigame = screen._match
	# Simulate a finished, mid-progress match.
	match_game._encounter.player_health = 3
	match_game._game_over = true
	match_game._ended = true
	var stale_encounter: EncounterState = match_game._encounter
	# Restart from the Settings panel (the signal the panel's button emits).
	screen._settings_screen().restart_pressed.emit()
	await await_idle_frame()
	# The match adopted the screen's fresh encounter and cleared the finished state.
	assert_object(match_game._encounter).is_not_same(stale_encounter)
	assert_object(match_game._encounter).is_same(GameSession.game_state.encounter)
	assert_bool(match_game._game_over).is_false()
	assert_bool(match_game._ended).is_false()
	assert_int(match_game._encounter.player_health).is_equal(match_game._encounter.player_max_health)
