extends MatchTestCase
## Tile tally routing into the active combatant's readouts.


# A damage match throws one flying glyph per damage cell at the struck portrait (into the popup overlay).
func test_damage_match_throws_tiles_at_portrait() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _DAMAGE_KIND)
	var before: int = game._popup_layer.get_child_count()
	game._on_cells_cleared(board, cells)
	# One glyph per damage cell, still alive a frame into the flight (not freed instantly).
	await game.get_tree().process_frame
	assert_int(game._popup_layer.get_child_count()).is_equal(before + cells.size())
	game.queue_free()


# A combatant's tally must only move its own portrait's readouts — the player's matches never show up
# under the opponent (the routing bug: a shared readout builder added the player tally to both).
func test_player_tally_banks_only_into_player_readout() -> void:
	var game := _make()
	await await_idle_frame()
	var player_before: int = int(game._player_readouts()[_COMBAT_KIND])
	var opponent_before: int = int(game._opponent_readouts()[_COMBAT_KIND])
	game._encounter.player.resources[_COMBAT_KIND].amount += 5
	assert_int(int(game._player_readouts()[_COMBAT_KIND])).is_equal(player_before + 5)
	assert_int(int(game._opponent_readouts()[_COMBAT_KIND])).is_equal(opponent_before)
	game.queue_free()


func test_opponent_tally_banks_only_into_opponent_readout() -> void:
	var game := _make()
	await await_idle_frame()
	var player_before: int = int(game._player_readouts()[_COMBAT_KIND])
	var opponent_before: int = int(game._opponent_readouts()[_COMBAT_KIND])
	game._encounter.opponent.resources[_COMBAT_KIND].amount += 5
	assert_int(int(game._opponent_readouts()[_COMBAT_KIND])).is_equal(opponent_before + 5)
	assert_int(int(game._player_readouts()[_COMBAT_KIND])).is_equal(player_before)
	game.queue_free()


# Cleared stat tiles bank into whichever combatant's turn it is, never the other's.
func test_clear_banks_to_active_combatant() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0)]
	var kind: int = _COMBAT_KIND
	_force_kind(board, cells, kind)

	# Turn 1 is the player's.
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.player.resources[kind].amount).is_equal(1)
	assert_int(game._encounter.opponent.resources[kind].amount).is_equal(0)

	# After a turn flips to the opponent, the same clear banks to them instead.
	game._encounter.advance_turn()
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.opponent)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.opponent.resources[kind].amount).is_equal(1)
	assert_int(game._encounter.player.resources[kind].amount).is_equal(1)
	game.queue_free()
