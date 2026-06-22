extends GdUnitTestSuite
## MatchMinigame (match-3). The board is an equal-frequency generator, so it always lays down a full
## field of tiles.

func _make() -> MatchMinigame:
	var scene: PackedScene = load("res://minigames/match/match.tscn")
	var game: MatchMinigame = scene.instantiate()
	game.board_seed = 4242
	add_child(game)
	return game

func test_board_fills_completely() -> void:
	var game := _make()
	await await_idle_frame()
	var state: GridState = game._session.state
	var placed: int = 0
	for y: int in 8:
		for x: int in 8:
			if state.get_object_at(0, x, y) != null:
				placed += 1
	assert_int(placed).is_equal(64)
	game.queue_free()

# Combat (kind 0) is a stat readout, so its number includes the matched-tile tally.
const _COMBAT_KIND: int = 0
# Scrap (kind 4) is the currency readout — it must accumulate matched tiles too (player), but the
# wallet-less opponent shows "—".
const _SCRAP_KIND: int = 4

# Matching scrap tiles banks into the player's scrap readout (regression: the scrap slot skipped the
# tally, so scrap matches never counted).
func test_scrap_tally_banks_into_player_readout() -> void:
	var game := _make()
	await await_idle_frame()
	var before: int = int(game._player_readouts()[_SCRAP_KIND])
	game._player_tally[_SCRAP_KIND] += 3
	assert_int(int(game._player_readouts()[_SCRAP_KIND])).is_equal(before + 3)
	game.queue_free()

# The wallet-less opponent always shows "—" for scrap, tally or not.
func test_opponent_scrap_stays_dashed() -> void:
	var game := _make()
	await await_idle_frame()
	assert_str(game._opponent_readouts()[_SCRAP_KIND]).is_equal("—")
	game._opponent_tally[_SCRAP_KIND] += 3
	assert_str(game._opponent_readouts()[_SCRAP_KIND]).is_equal("—")
	game.queue_free()

# A combatant's tally must only move its own portrait's readouts — the player's matches never show up
# under the opponent (the routing bug: a shared readout builder added the player tally to both).
func test_player_tally_banks_only_into_player_readout() -> void:
	var game := _make()
	await await_idle_frame()
	var player_before: int = int(game._player_readouts()[_COMBAT_KIND])
	var opponent_before: int = int(game._opponent_readouts()[_COMBAT_KIND])
	game._player_tally[_COMBAT_KIND] += 5
	assert_int(int(game._player_readouts()[_COMBAT_KIND])).is_equal(player_before + 5)
	assert_int(int(game._opponent_readouts()[_COMBAT_KIND])).is_equal(opponent_before)
	game.queue_free()

func test_opponent_tally_banks_only_into_opponent_readout() -> void:
	var game := _make()
	await await_idle_frame()
	var player_before: int = int(game._player_readouts()[_COMBAT_KIND])
	var opponent_before: int = int(game._opponent_readouts()[_COMBAT_KIND])
	game._opponent_tally[_COMBAT_KIND] += 5
	assert_int(int(game._opponent_readouts()[_COMBAT_KIND])).is_equal(opponent_before + 5)
	assert_int(int(game._player_readouts()[_COMBAT_KIND])).is_equal(player_before)
	game.queue_free()

# Cleared tiles bank into whichever combatant's turn it is, never the other's.
func test_clear_banks_to_active_combatant() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0)]
	var kind: int = game._kind_at(board, 0, 0)

	# Turn 1 is the player's.
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.PLAYER)
	game._on_cells_cleared(board, cells)
	assert_int(game._player_tally[kind]).is_equal(1)
	assert_int(game._opponent_tally[kind]).is_equal(0)

	# After a turn flips to the opponent, the same clear banks to them instead.
	game._encounter.advance_turn()
	assert_int(game._encounter.active_combatant()).is_equal(EncounterState.Combatant.OPPONENT)
	game._on_cells_cleared(board, cells)
	assert_int(game._opponent_tally[kind]).is_equal(1)
	assert_int(game._player_tally[kind]).is_equal(1)
	game.queue_free()
