extends MatchTestCase
## Scrap, damage, and warp banking from cleared tiles.


# Matching scrap tiles on the player's turn banks scrap into the wallet (the nav-bar currency).
func test_scrap_match_earns_wallet() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _SCRAP_KIND)
	var before: int = GameSession.game_state.wallet.scrap
	# Turn 1 is the player's — scrap goes to their wallet.
	game._on_cells_cleared(board, cells)
	assert_int(GameSession.game_state.wallet.scrap).is_equal(before + 3)
	game.queue_free()


# Matching damage tiles on the player's turn deals that much damage to the opponent's health.
func test_damage_match_hurts_opponent() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	_force_kind(board, cells, _DAMAGE_KIND)
	var opponent_max: int = game._encounter.opponent_max_health
	# Turn 1 is the player's — their damage hits the opponent.
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.opponent_health).is_equal(opponent_max - 4)
	assert_int(game._encounter.player_health).is_equal(game._encounter.player_max_health)
	game.queue_free()


# Matching Warp on the player's turn charges the shared meter (toward the player): a 3-run is one bar. Warp
# isn't a banked resource, so its tally slot stays zero.
func test_warp_match_charges_player() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.warp_meter.player_capacity = 4  # stand in for a warp core; modules seed this in a real encounter
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _WARP_KIND)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.warp_meter.value).is_equal(1)
	assert_int(game._encounter.player.resources[_WARP_KIND].amount).is_equal(0)
	game.queue_free()


# Bigger Warp matches charge more bars: a 5-match is three (the match size minus two).
func test_warp_match_scales_with_run() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.warp_meter.player_capacity = 4  # a warp core's capacity
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	_force_kind(board, cells, _WARP_KIND)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.warp_meter.value).is_equal(3)
	game.queue_free()


# Warp charges by the same match-size rule as everything else — a bent match counts whole, never by its
# longest line. An L of five warp tiles is a 5-match (three bars), not the 3-match its longest arm would
# read. (The regression: warp used to measure straight runs only, so this L charged a single bar.)
func test_warp_charges_by_match_size_not_line() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.warp_meter.player_capacity = 4  # a warp core's capacity
	var board: GridState = game._session.state
	var ell: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	_force_kind(board, ell, _WARP_KIND)
	game._on_cells_cleared(board, ell)
	assert_int(game._encounter.warp_meter.value).is_equal(3)  # 5-match - 2, not longest-arm(3) - 2 = 1
	game.queue_free()


# Campaign (no tug): the opponent's Warp only drains the player's progress, never below zero.
func test_campaign_opponent_warp_drains_player() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.warp_meter.player_capacity = 4  # a warp core's capacity, so the player's bars hold
	game._encounter.warp_meter.tug = false
	game._encounter.warp_meter.value = 3
	game._encounter.advance_turn()  # opponent's turn
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	_force_kind(board, cells, _WARP_KIND)
	game._on_cells_cleared(board, cells)  # 4-run = two bars, drains 3 -> 1
	assert_int(game._encounter.warp_meter.value).is_equal(1)
	game.queue_free()


# Quick Match (tug): the opponent's Warp pushes the shared meter to their end — it can go negative.
func test_quick_match_warp_is_a_tug() -> void:
	var game := _make()  # quick_match defaults true -> tug on
	await await_idle_frame()
	game._encounter.warp_meter.player_capacity = 4  # both starships carry a warp core in this tug
	game._encounter.warp_meter.opponent_capacity = 4
	assert_bool(game._encounter.warp_meter.tug).is_true()
	game._encounter.advance_turn()  # opponent's turn
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _WARP_KIND)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.warp_meter.value).is_equal(-1)
	assert_int(game._encounter.warp_meter.progress_of(false)).is_equal(1)
	game.queue_free()
