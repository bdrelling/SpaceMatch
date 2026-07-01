extends GdUnitTestSuite
## MatchGame (match-3). The board is an equal-frequency generator, so it always lays down a full
## field of tiles.


# Reset the shared GameSession singleton before each test so a fresh default game (starship + wallet) backs the
# run and tests don't leak state into each other.
func before_test() -> void:
	GameSession.start_new_game()


# A standalone encounter with default combatant starships, freed at test end. GameCoordinator builds the two
# [Starship] nodes; tests operate on its [EncounterState] directly (resources, no node-reaching).
func _encounter() -> EncounterState:
	var encounter: Encounter = auto_free(GameCoordinator.start_quick_match())
	return encounter.state


# Acts as a host mounting the match: opens an encounter on the session (a clone of the player starship vs the
# computer default) and binds the match to it, the way [Game] / [EncounterScreen] do.
func _host_bind(game: MatchGame) -> void:
	auto_free(GameCoordinator.start_quick_match())
	game.bind_session()


func _make(ruleset: Ruleset = null, mode := MatchBoardView.InputMode.SWAP, ai := true) -> MatchGame:
	var scene: PackedScene = load("res://systems/match/ui/match_game.tscn")
	var game: MatchGame = scene.instantiate()
	game.board_seed = 4242
	game.input_mode = mode
	# Insulate the existing behaviour tests from the spawn weights and extra-turn rule: a neutral
	# ruleset (no extra turns, uniform spawn) unless a test asks for a specific one.
	game.ruleset = ruleset if ruleset != null else RuleCatalog.default_ruleset()
	# Resolve actions instantly in tests so an ability's turn-handover isn't gated behind an animation beat.
	game.action_resolve_delay = 0.0
	# Most turn/ability tests isolate the logic from the AI opponent — a hot-seat opponent never auto-plays.
	game.ai_opponent = ai
	add_child(game)
	# Behaviour tests run on neutral rules: clear each fight starship's own ruleset (its extra-turn kit) so a 4+
	# match doesn't silently keep the board. Abilities stay — the AI ability tests read the starship's set.
	if game._encounter != null:
		if game._encounter.player != null:
			game._encounter.player.starship.ruleset = Ruleset.new()
		if game._encounter.opponent != null:
			game._encounter.opponent.starship.ruleset = Ruleset.new()
	return game


# Applies `amount` to `stat_name` on a combatant as a status-backed stat modifier (a unit-amount [Modifier]
# stacked `amount` times) — the test stand-in for an authored buff/debuff status.
func _buff(enc: EncounterState, combatant: Combatant, stat_name: StringName, amount: int) -> void:
	var status := Status.new()
	status.name = stat_name
	var stat := StarshipStat.new()
	stat.name = stat_name
	var modifier := Modifier.new()
	modifier.stat = stat
	modifier.operation = Modifier.Operation.ADD
	modifier.amount = 1.0
	status.modifiers.append(modifier)
	enc.add_status(combatant, status, amount)


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
const _SCRAP_KIND: int = 4
const _WARP_KIND: int = 5
const _DAMAGE_KIND: int = 6


# The [StarshipResource] backing a board tile kind — the type the resource/ability API now references. Looked
# up through the live catalog so a test reads exactly what the game banks.
func _resource(tile_kind: int) -> StarshipResource:
	return Catalogs.ability_resources.for_tile(tile_kind)


# The portraits show only the four colored stat tiles — scrap, warp, and damage aren't starship stats.
func test_portrait_shows_only_four_stat_readouts() -> void:
	var game := _make()
	await await_idle_frame()
	assert_int(game._player_readouts().size()).is_equal(4)
	assert_int(game._opponent_readouts().size()).is_equal(4)
	game.queue_free()


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
	game._encounter.player_warp_max = 4  # stand in for a warp core; modules seed this in a real encounter
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _WARP_KIND)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.warp).is_equal(1)
	assert_int(game._encounter.player.resources[_WARP_KIND].amount).is_equal(0)
	game.queue_free()


# Bigger Warp matches charge more bars: a 5-match is three (the match size minus two).
func test_warp_match_scales_with_run() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.player_warp_max = 4  # a warp core's capacity
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	_force_kind(board, cells, _WARP_KIND)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.warp).is_equal(3)
	game.queue_free()


# Warp charges by the same match-size rule as everything else — a bent match counts whole, never by its
# longest line. An L of five warp tiles is a 5-match (three bars), not the 3-match its longest arm would
# read. (The regression: warp used to measure straight runs only, so this L charged a single bar.)
func test_warp_charges_by_match_size_not_line() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.player_warp_max = 4  # a warp core's capacity
	var board: GridState = game._session.state
	var ell: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	_force_kind(board, ell, _WARP_KIND)
	game._on_cells_cleared(board, ell)
	assert_int(game._encounter.warp).is_equal(3)  # 5-match - 2, not longest-arm(3) - 2 = 1
	game.queue_free()


# Campaign (no tug): the opponent's Warp only drains the player's progress, never below zero.
func test_campaign_opponent_warp_drains_player() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.player_warp_max = 4  # a warp core's capacity, so the player's bars hold
	game._encounter.warp_tug = false
	game._encounter.warp = 3
	game._encounter.advance_turn()  # opponent's turn
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	_force_kind(board, cells, _WARP_KIND)
	game._on_cells_cleared(board, cells)  # 4-run = two bars, drains 3 -> 1
	assert_int(game._encounter.warp).is_equal(1)
	game.queue_free()


# Quick Match (tug): the opponent's Warp pushes the shared meter to their end — it can go negative.
func test_quick_match_warp_is_a_tug() -> void:
	var game := _make()  # quick_match defaults true -> tug on
	await await_idle_frame()
	game._encounter.player_warp_max = 4  # both starships carry a warp core in this tug
	game._encounter.opponent_warp_max = 4
	assert_bool(game._encounter.warp_tug).is_true()
	game._encounter.advance_turn()  # opponent's turn
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _WARP_KIND)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.warp).is_equal(-1)
	assert_int(game._encounter.warp_of(game._encounter.opponent)).is_equal(1)
	game.queue_free()


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


# The encounter opens on the player (turn 1), and after the player moves the AI
# opponent takes its own turn unprompted, rolling play into round 2.
func test_opponent_takes_its_turn_automatically() -> void:
	var game := _make()
	game.opponent_move_delay = 0.0
	await await_idle_frame()
	# The board pours in on ready (drop_in marks the view busy for ~0.6s); wait it
	# out so the player's move isn't swallowed as input-during-animation.
	var settle_ms: int = 0
	while game._match_view._busy and settle_ms < 2000:
		await await_millis(50)
		settle_ms += 50
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	# Play the player's turn with the same solver the AI uses for its own.
	var swap := game._session.find_interaction(GridInteraction.Gesture.SWIPE) as SwapInteraction
	var move: Array[Vector2i] = SwapSolver.best_move(game._session.state, swap)
	assert_array(move).is_not_empty()
	await game._match_view.perform_move(move)
	# The opponent now plays on its own; wait for its move and cascade to settle.
	var waited_ms: int = 0
	while game._encounter.round_number < 2 and waited_ms < 4000:
		await await_millis(100)
		waited_ms += 100
	assert_int(game._encounter.round_number).is_equal(2)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	game.queue_free()


# --- Rules: spawn weights and the extra-turn rule ---


# The standard MATCH-scope config: one-to-one scoring, reload split on, and warp (kind 5) rarer than every
# stat tile. Extra turns and abilities are NOT here — they're the starship's now (see the starship tests below).
func test_default_rules_match_the_designed_config() -> void:
	var ruleset := RuleCatalog.default_ruleset()
	# Extra turns moved off the match onto the starship — the match's own ruleset no longer carries one.
	assert_object(ruleset.find(&"extra_turn")).is_null()
	# Scoring is its own rule, one-to-one by default — a match of N is worth N (Fibonacci is opt-in).
	var scoring := ruleset.find(&"scoring") as ScoringRule
	assert_int(scoring.reward_for(6)).is_equal(6)
	assert_bool(scoring.formula is FibonacciScoringFormula).is_false()
	# Reloading a dead board splits it between both sides — the rule is present.
	assert_object(ruleset.find(&"reload_split")).is_not_null()
	# Spawn weights live on per-resource SpawnResourceRules (the nested Spawn set), composed into one pool —
	# warp is rarer than any stat tile.
	var weights := ruleset.aggregate(&"spawn_contribution")
	var warp_weight: int = weights[_WARP_KIND]
	for stat_kind: int in 4:
		var stat_weight: int = weights[stat_kind]
		assert_int(warp_weight).is_less(stat_weight)


# The default starship carries the standard hull kit: a match-4 extra-turn rule. This is where extra turns
# live now — on the starship, composed into the match per turn — not on the match's own ruleset.
func test_default_starship_carries_the_extra_turn_kit() -> void:
	var starship := GameSession.game_state.starship
	var extra_turn := starship.ruleset.find(&"extra_turn") as ExtraTurnRule
	assert_object(extra_turn).is_not_null()
	assert_int(extra_turn.min_match).is_equal(4)


# A run of four or more keeps the board with the mover (the extra-turn rule), so the turn doesn't pass.
func test_match_of_four_grants_another_turn() -> void:
	var game := _make(_extra_turn_rules(4))
	await await_idle_frame()
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	game._move_max_run = 4
	game._on_move_resolved(true, 4)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	assert_int(game._encounter.round_number).is_equal(1)
	game.queue_free()


# A run shorter than the threshold passes the turn as normal. Line-shift mode keeps the AI from auto-
# playing the handed-off turn, so the assertion sees the bare turn advance.
func test_match_below_threshold_passes_the_turn() -> void:
	var game := _make(_extra_turn_rules(4), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	game._move_max_run = 3
	game._on_move_resolved(true, 3)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.opponent)
	game.queue_free()


# Extra turns are the acting starship's, composed into the match per turn. With NO extra-turn rule on the
# match (neutral), a player starship that carries one still keeps the board on a 4-match.
func test_extra_turn_rule_is_starship_based() -> void:
	var game := _make(RuleCatalog.default_ruleset(), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	var starship_set := Ruleset.new()
	var rule := ExtraTurnRule.new()
	rule.min_match = 4
	starship_set.add(rule)
	game._encounter.player.starship.ruleset = starship_set
	game._move_max_run = 4
	game._on_move_resolved(true, 4)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)  # starship rule kept the board
	game.queue_free()


# Default + per-starship override (mirroring selection): the match says a 5 grants another turn, the player starship's
# rule says 3. On the player's turn the starship's rule overrides the match's by rule_name, so a 3 keeps the board.
func test_starship_rule_overrides_the_match_rule_by_name() -> void:
	var game := _make(_extra_turn_rules(5), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	var starship_set := Ruleset.new()
	var loose := ExtraTurnRule.new()
	loose.min_match = 3
	starship_set.add(loose)
	game._encounter.player.starship.ruleset = starship_set
	game._move_max_run = 3
	game._on_move_resolved(true, 3)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	game.queue_free()


# _largest_match is the single way a match's size is measured — every consumer uses it. In line mode a match
# is a straight run, and runs that share a cell merge: an L is 5, a T (4-arm + 3-arm) is 6. Two parallel runs
# that share no cell (a 3x2 block) stay two 3s — NOT a 6, which a blind flood-fill would wrongly report.
func test_match_size_merges_intersecting_runs_not_parallel_ones() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	# A straight run of four is four of a kind.
	var row: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	_force_kind(board, row, 0)
	assert_int(game._largest_match(board, row, false)).is_equal(4)
	# An L — three across, two down sharing the corner — is five of a kind (its longest arm is only three).
	var ell: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)]
	_force_kind(board, ell, 0)
	assert_int(game._largest_match(board, ell, false)).is_equal(5)
	# A T — a 4-run crossing a 3-run at a shared cell — is six total tiles.
	var tee: Array[Vector2i] = [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(1, 5), Vector2i(1, 7)]
	_force_kind(board, tee, 0)
	assert_int(game._largest_match(board, tee, false)).is_equal(6)
	# A 3x2 block: two parallel 3-runs that share no cell. In line mode it's a match-3, never a 6.
	var block: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
	_force_kind(board, block, 0)
	assert_int(game._largest_match(board, block, false)).is_equal(3)
	game.queue_free()


# Same six cells, cleared two ways: dragged whole (is_path) the path IS the match, so it's a 6; cleared as
# straight lines it's two 3s. The size must come from how it was cleared, never from re-reading the cells.
func test_match_size_path_clears_count_the_whole_path() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var block: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
	_force_kind(board, block, 0)
	assert_int(game._largest_match(board, block, true)).is_equal(6)  # drag: the path is one match-6
	assert_int(game._largest_match(board, block, false)).is_equal(3)  # line: two parallel 3-runs
	game.queue_free()


# A diagonal run is a match only when the board matches along diagonals (the one allow_diagonal knob);
# orthogonally those cells form no run at all, so they read as singletons.
func test_match_size_diagonal_runs_follow_the_knob() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var diag: Array[Vector2i] = [Vector2i(4, 2), Vector2i(5, 3), Vector2i(6, 4)]
	_force_kind(board, diag, 0)
	game.allow_diagonal = false
	assert_int(game._largest_match(board, diag, false)).is_equal(1)
	game.allow_diagonal = true
	assert_int(game._largest_match(board, diag, false)).is_equal(3)
	game.queue_free()


# Spawn weights bias the pool: with the default ruleset the weight-2 warp tile is drawn far less often
# than a weight-20 stat tile over many refills.
func test_spawn_weights_bias_the_pool() -> void:
	var game := _make(RuleCatalog.default_ruleset())
	await await_idle_frame()
	var warp: int = 0
	var combat: int = 0
	for _i: int in 800:
		var kind: int = game._pick_kind()
		if kind == _WARP_KIND:
			warp += 1
		elif kind == 0:
			combat += 1
	assert_int(warp).is_less(combat)
	game.queue_free()


# --- Abilities ---


# The standard hull kit grants one ability per stat tile (red/yellow/green/blue = 0/1/2/3) — Target Lock /
# Evasive Maneuvers / Siphon / Shields — plus a fifth Disruptor that also spends green. Abilities are the
# starship's now, so they're read off the default starship, not the match rules.
func test_default_starship_defines_the_standard_abilities() -> void:
	var abilities := GameSession.game_state.starship.abilities
	assert_int(abilities.size()).is_equal(5)
	for i: int in 4:
		assert_int((abilities[i].costs[0].resource as StarshipResource).id).is_equal(i)
	assert_bool(abilities[0].effects[0].action is DamageBuffAction).is_true()
	assert_bool(abilities[1].effects[0].action is DodgeAction).is_true()
	assert_bool(abilities[2].effects[0].action is DrainAction).is_true()
	assert_bool(abilities[3].effects[0].action is ShieldAction).is_true()
	assert_int(abilities[1].costs[0].amount).is_equal(5)  # Evasive Maneuvers is the cheap one
	assert_int(abilities[3].costs[0].amount).is_equal(10)  # Shields
	# Disruptor: disables an opponent module for 3 turns, paid for with green (the science tile).
	var disruptor := abilities[4]
	assert_bool(disruptor.effects[0].action is DisableAction).is_true()
	assert_int((disruptor.costs[0].resource as StarshipResource).id).is_equal(2)
	assert_int((disruptor.effects[0].action as DisableAction).turns).is_equal(3)


# Using an ability spends its tiles from the player's tally and deals its damage to the opponent. Line-shift
# keeps the AI from auto-playing the handed-off turn, so the spend/damage are read without async interference.
func test_ability_use_spends_gems_and_deals_damage() -> void:
	var game := _make(RuleCatalog.default_ruleset(), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	var ability := MatchAbilities.attack("Test", _resource(_COMBAT_KIND), 10, 5)
	game._encounter.player.resources[_COMBAT_KIND].amount = 12
	var max_health: int = game._encounter.opponent_max_health
	game._on_ability_pressed(ability)
	assert_int(game._encounter.player.resources[_COMBAT_KIND].amount).is_equal(2)
	assert_int(game._encounter.opponent_health).is_equal(max_health - 5)
	game.queue_free()


# Using an ability ends the user's turn, handing the board over. (Keeping the turn is no longer an ability
# flag — it'll come from a future extra-turn effect.)
func test_using_an_ability_ends_the_turn() -> void:
	var game := _make(RuleCatalog.default_ruleset(), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	var ability := MatchAbilities.attack("Test", _resource(_COMBAT_KIND), 5, 5)
	game._encounter.player.resources[_COMBAT_KIND].amount = 10
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	game._use_ability(game._encounter.player, ability)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.opponent)
	game.queue_free()


# The opponent picks the affordable attack on its turn — nothing when broke, an attack it can pay for once
# it has the tiles (the AI's ability use).
func test_opponent_picks_an_affordable_ability() -> void:
	var game := _make(RuleCatalog.default_ruleset())
	await await_idle_frame()
	assert_object(game._best_affordable_ability(game._encounter.opponent)).is_null()
	game._encounter.opponent.resources[1].amount = 5  # enough for Evasive Maneuvers (kind 1, the cost-5 ability)
	var pick: Ability = game._best_affordable_ability(game._encounter.opponent)
	assert_object(pick).is_not_null()
	assert_int((pick.costs[0].resource as StarshipResource).id).is_equal(1)
	game.queue_free()


# The AI won't refresh a dodge it already has — so it can't sit on Evasive Maneuvers every turn and make the
# dodge feel permanent. With only enough for Evasive and a dodge already up, it picks nothing (and plays the board).
func test_opponent_does_not_recast_an_active_dodge() -> void:
	var game := _make(RuleCatalog.default_ruleset())
	await await_idle_frame()
	game._encounter.opponent.resources[1].amount = 5  # enough for Evasive Maneuvers only
	assert_object(game._best_affordable_ability(game._encounter.opponent)).is_not_null()
	game._encounter.set_dodge(game._encounter.opponent, true)
	assert_object(game._best_affordable_ability(game._encounter.opponent)).is_null()
	game.queue_free()


# --- Scoring & cascades ---


# The Fibonacci formula rewards a match by its size on the sequence (3→3, 4→5, 5→8, 6→13, 7→21).
func test_fibonacci_match_rewards() -> void:
	var ruleset := RuleCatalog.default_ruleset()
	(ruleset.find(&"scoring") as ScoringRule).formula = FibonacciScoringFormula.new()
	var game := _make(ruleset)
	await await_idle_frame()
	assert_int(game._reward_for(3)).is_equal(3)
	assert_int(game._reward_for(4)).is_equal(5)
	assert_int(game._reward_for(5)).is_equal(8)
	assert_int(game._reward_for(6)).is_equal(13)
	assert_int(game._reward_for(7)).is_equal(21)
	game.queue_free()


# Scoring is one-to-one by default (the default ruleset's ScoringRule is linear): a match rewards one per tile.
func test_rewards_are_linear_by_default() -> void:
	var game := _make()  # default ruleset — linear scoring
	await await_idle_frame()
	assert_int(game._reward_for(4)).is_equal(4)
	assert_int(game._reward_for(7)).is_equal(7)
	game.queue_free()


# Reloading a dead board splits its tiles between the combatants — each gets floor(count / 2) of every stat
# kind into their tally.
func test_reload_splits_board_resources_between_players() -> void:
	var game := _make()  # the default ruleset includes the reload-split rule
	await await_idle_frame()
	var board: GridState = game._session.state
	var expected: Dictionary = {}
	for y: int in 8:
		for x: int in 8:
			var k: int = game._kind_at(board, x, y)
			if k >= 0 and k <= 3:
				expected[k] = expected.get(k, 0) + 1
	game._split_board_resources()
	for k: int in expected:
		var each: int = expected[k] / 2  # floor; the odd tile is discarded
		assert_int(game._encounter.player.resources[k].amount).is_equal(each)
		assert_int(game._encounter.opponent.resources[k].amount).is_equal(each)
	game.queue_free()


# An ability the player can't afford does nothing — no damage, no tiles drained below the cost.
func test_ability_unaffordable_does_nothing() -> void:
	var game := _make()
	await await_idle_frame()
	var ability := MatchAbilities.attack("Test", _resource(_COMBAT_KIND), 10, 5)
	game._encounter.player.resources[_COMBAT_KIND].amount = 3
	var health_before: int = game._encounter.opponent_health
	game._on_ability_pressed(ability)
	assert_int(game._encounter.player.resources[_COMBAT_KIND].amount).is_equal(3)
	assert_int(game._encounter.opponent_health).is_equal(health_before)
	game.queue_free()


# --- Combat state: shield, dodge, win/lose ---


# Shield soaks damage before health, and overflow spills through to health.
func test_shield_absorbs_damage_before_health() -> void:
	var enc := _encounter()
	enc.add_shield(enc.player, 10)
	assert_int(enc.deal_damage(enc.player, 6)).is_equal(0)  # fully soaked
	assert_int(enc.shield_of(enc.player)).is_equal(4)
	assert_int(enc.player_health).is_equal(enc.player_max_health)
	assert_int(enc.deal_damage(enc.player, 10)).is_equal(6)  # 4 soaked, 6 to health
	assert_int(enc.shield_of(enc.player)).is_equal(0)
	assert_int(enc.player_health).is_equal(enc.player_max_health - 6)


# Dodge negates the next attack whole and is then spent; the one after lands normally.
func test_dodge_negates_the_next_attack() -> void:
	var enc := _encounter()
	enc.set_dodge(enc.player, true)
	assert_int(enc.deal_damage(enc.player, 8)).is_equal(-1)  # dodged
	assert_int(enc.player_health).is_equal(enc.player_max_health)
	assert_bool(enc.dodge_of(enc.player)).is_false()  # consumed
	enc.deal_damage(enc.player, 5)
	assert_int(enc.player_health).is_equal(enc.player_max_health - 5)


# --- Combat through the effect engine (wiring) ---


# Damage runs through the engine pipeline: the hit lands on the combatant's `health` stat (its live hull on
# current_stats), so it's the engine's ModifyStat path, not a bespoke health field.
func test_damage_lands_on_the_health_stat() -> void:
	var enc := _encounter()
	var before: int = enc.player.current_stats.get_stat(Stats.health)
	enc.deal_damage(enc.player, 7)
	assert_int(enc.player.current_stats.get_stat(Stats.health)).is_equal(before - 7)
	assert_int(enc.player_health).is_equal(before - 7)  # the read-through agrees with the stat


# Shield is the engine's `shield` pool stat soaked by the shield status's AbsorbStep: granting writes the stat
# and applies the status (so the step is in the pipeline); a hit drains the stat through the pipeline.
func test_shield_is_a_pool_stat_drained_by_absorb_step() -> void:
	var enc := _encounter()
	enc.add_shield(enc.player, 8)
	assert_int(enc.player.current_stats.get_stat(Stats.block)).is_equal(8)  # stored as the shield pool stat
	assert_int(enc.player.status_count(&"shield")).is_equal(8)  # shield status present (AbsorbStep collected)
	enc.deal_damage(enc.player, 5)
	assert_int(enc.player.current_stats.get_stat(Stats.block)).is_equal(3)  # the AbsorbStep drained the pool
	assert_int(enc.player_health).is_equal(enc.player_max_health)  # nothing reached health
	enc.deal_damage(enc.player, 3)  # empties the pool
	assert_int(enc.player.status_count(&"shield")).is_equal(0)  # status removed once the pool is gone


# Dodge is a `dodge` status consumed by its on-hit decay (the WhenHitHook the host raises on a hit), not a
# hand-reset flag: it negates the whole hit and the engine drops the stack.
func test_dodge_status_consumed_by_when_hit_decay() -> void:
	var enc := _encounter()
	enc.set_dodge(enc.player, true)
	assert_int(enc.player.status_count(&"dodge")).is_equal(1)
	assert_int(enc.deal_damage(enc.player, 9)).is_equal(-1)  # negated whole
	assert_int(enc.player.status_count(&"dodge")).is_equal(0)  # engine decay consumed the stack
	assert_int(enc.player_health).is_equal(enc.player_max_health)


# Dodge guards only the opponent's turn that follows it: it survives into the opponent's turn, then expires
# when the owner's turn comes back around (so it can't last forever).
func test_dodge_expires_when_owners_turn_returns() -> void:
	var enc := _encounter()
	enc.set_dodge(enc.player, true)
	enc.advance_turn()  # player's turn → opponent's; the player is still evading through it
	assert_bool(enc.dodge_of(enc.player)).is_true()
	enc.advance_turn()  # opponent's turn → player's again; the dodge expires
	assert_bool(enc.dodge_of(enc.player)).is_false()


# A damage match against a dodging opponent (the in-game path, not just deal_damage) spends the dodge: the
# match is negated, and the opponent's badge clears.
func test_damage_match_consumes_opponent_dodge() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.set_dodge(game._encounter.opponent, true)
	var max_health: int = game._encounter.opponent_max_health
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _DAMAGE_KIND)
	game._on_cells_cleared(board, cells)  # player's turn — damage targets the opponent
	assert_int(game._encounter.opponent_health).is_equal(max_health)  # dodged, no damage
	assert_bool(game._encounter.dodge_of(game._encounter.opponent)).is_false()  # consumed
	assert_bool(game._opponent_portrait._dodge_indicator.visible).is_false()  # badge cleared
	game.queue_free()


# The EVADE badge tracks the encounter's dodge state: hidden by default, shown once the combatant is armed —
# and when shown it lays out to a real size (the overlay must grow onto the portrait, not clip off its edge).
func test_portrait_shows_dodge_badge() -> void:
	var game := _make()
	await await_idle_frame()
	assert_bool(game._opponent_portrait._dodge_indicator.visible).is_false()
	game._encounter.set_dodge(game._encounter.opponent, true)
	game._refresh_dodge()
	await await_idle_frame()  # let the overlay lay out so its size reflects its content
	var badge: Control = game._opponent_portrait._dodge_indicator
	assert_bool(badge.visible).is_true()
	assert_float(badge.size.x).is_greater(0.0)  # actually on-panel, not collapsed/clipped to nothing
	assert_float(badge.size.y).is_greater(0.0)
	game.queue_free()


# A dodge survives the OTHER combatant's full extra-turn chain — each match-4 keeps the board, so no handover
# happens — then expires the instant the turn genuinely hands back to the dodge's owner, never beyond it. This
# is the "does it linger past the next turn?" case: it does not.
func test_dodge_survives_extra_turns_then_clears_on_handover() -> void:
	var game := _make(_extra_turn_rules(4), MatchBoardView.InputMode.SWAP, false)
	await await_idle_frame()
	# Hand the board to the opponent, then arm the player's dodge guarding the opponent's coming turn(s).
	game._encounter.advance_turn()
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.opponent)
	game._encounter.set_dodge(game._encounter.player, true)
	game._refresh_dodge()
	assert_bool(game._player_portrait._dodge_indicator.visible).is_true()
	# Opponent chains two match-4s — each keeps the board, so the turn never passes and the dodge holds.
	game._move_max_run = 4
	game._on_move_resolved(true, 4)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.opponent)
	assert_bool(game._encounter.dodge_of(game._encounter.player)).is_true()
	game._move_max_run = 4
	game._on_move_resolved(true, 4)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.opponent)
	assert_bool(game._encounter.dodge_of(game._encounter.player)).is_true()
	assert_bool(game._player_portrait._dodge_indicator.visible).is_true()
	# A move below the threshold finally hands the board back to the player — the dodge expires right then.
	game._move_max_run = 3
	game._on_move_resolved(true, 3)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	assert_bool(game._encounter.dodge_of(game._encounter.player)).is_false()
	assert_bool(game._player_portrait._dodge_indicator.visible).is_false()
	game.queue_free()


# The encounter is over once a combatant is out of health, and names the loser.
func test_encounter_over_when_a_combatant_falls() -> void:
	var enc := _encounter()
	assert_bool(enc.is_over()).is_false()
	enc.deal_damage(enc.opponent, enc.opponent_max_health)
	assert_bool(enc.is_over()).is_true()
	assert_object(enc.defeated()).is_same(enc.opponent)


# Filling warp lets the player Jump — expending the meter and winning the encounter outright.
func test_player_jump_at_full_warp_wins() -> void:
	var enc := _encounter()
	enc.player_warp_max = 4  # a warp core grants capacity (modules seed this in a real encounter)
	enc.add_warp(enc.player, enc.player_warp_max)
	assert_bool(enc.can_jump(enc.player)).is_true()
	enc.jump(enc.player)
	assert_bool(enc.is_over()).is_true()
	assert_object(enc.defeated()).is_same(enc.opponent)  # the player won
	assert_int(enc.warp).is_equal(0)  # expended


# The opponent can only Jump in a tug (Quick Match); Campaign never lets their warp win.
func test_opponent_jump_only_in_a_tug() -> void:
	var enc := _encounter()
	enc.opponent_warp_max = 4
	enc.warp_tug = false
	enc.warp = -enc.opponent_warp_max
	assert_bool(enc.can_jump(enc.opponent)).is_false()
	enc.warp_tug = true
	assert_bool(enc.can_jump(enc.opponent)).is_true()
	enc.jump(enc.opponent)
	assert_object(enc.defeated()).is_same(enc.player)  # the opponent won


# Without a warp core (zero capacity) a starship can't warp at all: matched warp banks nothing and Jump stays out.
func test_no_warp_without_a_core() -> void:
	var enc := _encounter()  # a fresh encounter carries no warp capacity
	enc.add_warp(enc.player, 10)
	assert_int(enc.warp).is_equal(0)  # clamped to a zero capacity — nothing banks
	assert_bool(enc.can_jump(enc.player)).is_false()


# Each side fills toward its own capacity: a six-bar core and a four-bar core Jump at different fills.
func test_warp_capacity_is_per_side() -> void:
	var enc := _encounter()
	enc.warp_tug = true
	enc.player_warp_max = 4
	enc.opponent_warp_max = 6
	enc.add_warp(enc.player, 4)
	assert_bool(enc.can_jump(enc.player)).is_true()  # full at 4
	enc.warp = 0
	enc.add_warp(enc.opponent, 4)
	assert_bool(enc.can_jump(enc.opponent)).is_false()  # 4 of 6, not yet
	enc.add_warp(enc.opponent, 2)
	assert_bool(enc.can_jump(enc.opponent)).is_true()  # full at 6


# The Warp Core module grants warp capacity — guards the authored content the model depends on.
func test_warp_core_module_grants_capacity() -> void:
	var core := load("res://data/modules/warp_core_item_blueprint.tres") as ModuleBlueprint
	assert_int(core.stats.warp_capacity).is_equal(4)


# --- Ability effects (integration) ---


# Shields grants shield, which then soaks a hit before health.
func test_shield_ability_grants_and_absorbs() -> void:
	var game := _make(RuleCatalog.default_ruleset(), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	var shield_ability := MatchAbilities.shield("Shields", _resource(3), 5, 10)
	game._encounter.player.resources[3].amount = 5
	game._use_ability(game._encounter.player, shield_ability)
	assert_int(game._encounter.shield_of(game._encounter.player)).is_equal(10)
	game._encounter.deal_damage(game._encounter.player, 6)
	assert_int(game._encounter.shield_of(game._encounter.player)).is_equal(4)
	assert_int(game._encounter.player_health).is_equal(game._encounter.player_max_health)
	game.queue_free()


# Target Lock raises the user's effective DAMAGE stat (a temporary buff layer), which the damage rule adds to
# every hit.
func test_target_lock_buffs_tile_damage() -> void:
	var game := _make()  # neutral — linear scoring, so a 3-match deals 3 before the bonus
	await await_idle_frame()
	game._encounter.add_status(game._encounter.player, EncounterState.TARGET_LOCK, 2)
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _DAMAGE_KIND)
	var max_health: int = game._encounter.opponent_max_health
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.opponent_health).is_equal(max_health - 5)  # 3 tiles + 2 damage stat
	game.queue_free()


# The effective DAMAGE stat is permanent profile + temporary buffs: a starship that contributes damage hits for it.
func test_effective_stats_layer_buffs_on_base() -> void:
	var enc := _encounter()
	var base := StarshipStats.new()
	base.power = 3
	_buff(enc, enc.player, &"power", 2)
	assert_int(enc.effective_stats(enc.player, base).power).is_equal(5)
	# A negative buff debuffs; the opponent's layer is independent.
	_buff(enc, enc.player, &"power", -4)
	assert_int(enc.effective_stats(enc.player, base).power).is_equal(1)
	assert_int(enc.effective_stats(enc.opponent, base).power).is_equal(3)


# Each colored tile is bound to a stat; scrap and warp tiles carry none.
func test_stat_for_tile_mapping() -> void:
	assert_object(Stats.for_tile(0)).is_same(Stats.power)
	assert_object(Stats.for_tile(1)).is_same(Stats.speed)
	assert_object(Stats.for_tile(2)).is_same(Stats.sensors)
	assert_object(Stats.for_tile(3)).is_same(Stats.defense)
	assert_object(Stats.for_tile(6)).is_same(Stats.weapons)
	assert_object(Stats.for_tile(_SCRAP_KIND)).is_null()
	assert_object(Stats.for_tile(_WARP_KIND)).is_null()


# A matched colored tile banks reward_for(N) + the mover's effective stat for that tile: +4 Power, match 3 → 7.
func test_matched_tile_resource_includes_stat_bonus() -> void:
	var game := _make()  # neutral, one-to-one scoring; no session, so base profile is empty
	await await_idle_frame()
	_buff(game._encounter, game._encounter.player, &"power", 4)
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, 0)  # combat tile -> POWER
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.player.resources[0].amount).is_equal(7)  # 3 matched + 4 Power
	game.queue_free()


# End to end: disabling a module drops its stat from the player's profile, so matches bank less. The default
# loadout's Engine gives +4 Speed (propulsion tile); disable its cell and a propulsion match loses that bonus.
func test_disabling_a_module_lowers_its_tile_haul() -> void:
	var game := _make()
	await await_idle_frame()
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, 1)  # propulsion tile -> SPEED, which the Engine contributes +4
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.player.resources[1].amount).is_equal(7)  # 3 matched + 4 Speed (Engine)
	# Knock out the Engine (authored at (2, 4)); its Speed no longer counts, so the same match banks just 3.
	game._encounter.disable_cell(game._encounter.player, Vector2i(2, 4), 3)
	_force_kind(board, cells, 1)
	game._on_cells_cleared(board, cells)
	assert_int(game._encounter.player.resources[1].amount).is_equal(10)  # prior 7 + (3 matched + 0 Speed)
	game.queue_free()


# Siphon removes its magnitude from each of the opponent's four stat resources.
func test_siphon_drains_opponent_resources() -> void:
	var game := _make(RuleCatalog.default_ruleset(), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	for k: int in 4:
		game._encounter.opponent.resources[k].amount = 5
	var drain := MatchAbilities.drain("Siphon", _resource(2), 5, 2)
	game._encounter.player.resources[2].amount = 5
	game._use_ability(game._encounter.player, drain)
	for k: int in 4:
		assert_int(game._encounter.opponent.resources[k].amount).is_equal(3)
	game.queue_free()


# Disruptor disables one of the opponent's modules: it records a single disabled cell on the opponent's
# grid, and the module covering that cell is reported deactivated (it'll stop counting toward their stats).
func test_disruptor_disables_an_opponent_module() -> void:
	var game := _make(RuleCatalog.default_ruleset(), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	var disrupt := MatchAbilities.disable("Disruptor", _resource(2), 5, 3)
	game._encounter.player.resources[2].amount = 5
	assert_int(game._encounter.disabled_cells_of(game._encounter.opponent).size()).is_equal(0)
	game._use_ability(game._encounter.player, disrupt)
	var disabled: Array[Vector2i] = game._encounter.disabled_cells_of(game._encounter.opponent)
	assert_int(disabled.size()).is_equal(1)
	var grid: StarshipLoadout = game._opponent_starship().loadout
	assert_object(grid.module_at(disabled[0])).is_not_null()  # it landed on a real module
	var down: int = 0
	for module_state: ModuleState in grid.modules:
		if not grid.enabled(module_state, disabled):
			down += 1
	assert_int(down).is_equal(1)  # exactly the one module is deactivated
	game.queue_free()


# A disabled cell counts down one per turn and re-enables when it hits zero — and only on the targeted side.
func test_disabled_cell_counts_down_and_re_enables() -> void:
	var enc := _encounter()
	enc.disable_cell(enc.opponent, Vector2i(2, 0), 3)
	assert_array(enc.disabled_cells_of(enc.opponent)).contains([Vector2i(2, 0)])
	enc.advance_turn()  # 3 -> 2
	enc.advance_turn()  # 2 -> 1
	assert_int(enc.disabled_cells_of(enc.opponent).size()).is_equal(1)
	enc.advance_turn()  # 1 -> 0, re-enabled
	assert_int(enc.disabled_cells_of(enc.opponent).size()).is_equal(0)
	assert_int(enc.disabled_cells_of(enc.player).size()).is_equal(0)


# A lethal match ends the Quick Match: the encounter is over and play is frozen.
func test_lethal_match_ends_the_quick_match() -> void:
	var game := _make()  # quick_match defaults true
	await await_idle_frame()
	game._encounter.opponent_health = 1
	var board: GridState = game._session.state
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_force_kind(board, cells, _DAMAGE_KIND)
	game._on_cells_cleared(board, cells)  # deals 3, opponent to 0
	game._on_move_resolved(true, 3)
	assert_bool(game._encounter.is_over()).is_true()
	assert_bool(game._game_over).is_true()
	game.queue_free()


# Restart clears the game-over state, resets the encounter, and zeroes both tallies.
func test_restart_resets_the_encounter() -> void:
	var game := _make()
	await await_idle_frame()
	game._encounter.player.resources[0].amount = 9
	game._encounter.player_health = 3
	game._encounter.add_shield(game._encounter.player, 5)
	game._game_over = true
	game._restart_encounter()
	assert_int(game._encounter.player_health).is_equal(game._encounter.player_max_health)
	assert_int(game._encounter.shield_of(game._encounter.player)).is_equal(0)
	assert_int(game._encounter.player.resources[0].amount).is_equal(0)
	assert_bool(game._game_over).is_false()
	game.queue_free()


# The Settings-menu Restart rebuilds the session and rebinds every screen. A re-bind after a game-over has to
# clear the game-over/ended flags and adopt the fresh encounter — the menu Restart that used to do nothing
# because bind_session only swapped the encounter and left the frozen board (and _game_over) standing.
func test_rebind_restarts_a_finished_match() -> void:
	var game := _make()
	_host_bind(game)  # initial mount
	await await_idle_frame()
	game._encounter.player_health = 3
	game._game_over = true
	game._ended = true
	# The shell reopens the encounter and rebinds on Restart.
	_host_bind(game)
	await await_idle_frame()
	assert_bool(game._game_over).is_false()
	assert_bool(game._ended).is_false()
	assert_int(game._encounter.player_health).is_equal(game._encounter.player_max_health)
	game.queue_free()


# Overwrites the kind of each given cell's tile in place — for building a known run to measure.
func _force_kind(board: GridState, cells: Array[Vector2i], kind: int) -> void:
	for cell: Vector2i in cells:
		var tile: GridObjectState = board.get_object_at(0, cell.x, cell.y)
		tile.set("kind", kind)
		tile.state["kind"] = kind


# The solver returns a swap that the match condition agrees is a match.
func test_solver_finds_a_matching_swap() -> void:
	var condition := MatchLineCondition.new()
	condition.min_run_length = 3
	# Rows R R G / B G R / G B R — swapping (2,0) with (2,1) completes R R R on top.
	var state := _board(3, 3, "RRGBGRGBR")
	var swap := SwapInteraction.new()
	swap.match_condition = condition
	var move: Array[Vector2i] = SwapSolver.best_move(state, swap)
	assert_array(move).is_not_empty()
	assert_bool(_swap_makes_match(state, condition, move[0], move[1])).is_true()


# A board too small for any run returns no move (the dead-board signal to pass).
func test_solver_returns_empty_when_no_swap_matches() -> void:
	var condition := MatchLineCondition.new()
	condition.min_run_length = 3
	var state := _board(2, 2, "RGBY")
	var swap := SwapInteraction.new()
	swap.match_condition = condition
	assert_array(SwapSolver.best_move(state, swap)).is_empty()


# count_moves reports how many adjacent swaps make a match — at least one on a board with a ready move.
func test_count_moves_counts_available_swaps() -> void:
	var condition := MatchLineCondition.new()
	condition.min_run_length = 3
	# RRGBGRGBR — swapping (2,0) with (2,1) completes RRR on the top row, so a move exists.
	var state := _board(3, 3, "RRGBGRGBR")
	var swap := SwapInteraction.new()
	swap.match_condition = condition
	assert_int(SwapSolver.count_moves(state, swap)).is_greater(0)


# A board too small for any run has zero moves — the dead-board signal that triggers a reshuffle.
func test_count_moves_zero_on_dead_board() -> void:
	var condition := MatchLineCondition.new()
	condition.min_run_length = 3
	var state := _board(2, 2, "RGBY")
	var swap := SwapInteraction.new()
	swap.match_condition = condition
	assert_int(SwapSolver.count_moves(state, swap)).is_equal(0)


# --- Rules engine ---


# A Ruleset carrying a single ExtraTurnRule — the migrated form of the old flat knob.
func _extra_turn_rules(min_match: int) -> Ruleset:
	var ruleset := Ruleset.new()
	var rule := ExtraTurnRule.new()
	rule.min_match = min_match
	ruleset.add(rule)
	return ruleset


# A ruleset runs only the rules whose phase matches the one fired, and rules report results on the context.
func test_ruleset_runs_only_matching_phase() -> void:
	var ruleset := Ruleset.new()
	var rule := ExtraTurnRule.new()  # phase MOVE_RESOLVED, min_match 3
	rule.min_match = 3
	ruleset.add(rule)
	var match_context := MatchRuleContext.new()
	match_context.max_run = 4
	# A non-matching phase leaves the context untouched.
	ruleset.run(MatchPhase.ON_CLEAR, match_context)
	assert_bool(match_context.go_again).is_false()
	# The rule's own phase fires it, and it writes its result back.
	ruleset.run(MatchPhase.MOVE_RESOLVED, match_context)
	assert_bool(match_context.go_again).is_true()
	assert_str(match_context.go_again_reason).is_equal("Match-4")


# A disabled rule stays in the set but doesn't fire — the cheap on/off.
func test_disabled_rule_does_not_fire() -> void:
	var ruleset := Ruleset.new()
	var rule := ExtraTurnRule.new()
	rule.min_match = 3
	rule.enabled = false
	ruleset.add(rule)
	var match_context := MatchRuleContext.new()
	match_context.max_run = 9
	ruleset.run(MatchPhase.MOVE_RESOLVED, match_context)
	assert_bool(match_context.go_again).is_false()


# Rules can be swapped at runtime — remove by name, add a retuned one — which is how play changes its own
# rules mid-game.
func test_ruleset_swaps_rules_at_runtime() -> void:
	var ruleset := Ruleset.new()
	var strict := ExtraTurnRule.new()
	strict.min_match = 5
	ruleset.add(strict)
	var match_context := MatchRuleContext.new()
	match_context.max_run = 4
	ruleset.run(MatchPhase.MOVE_RESOLVED, match_context)
	assert_bool(match_context.go_again).is_false()  # a 4-run misses the strict threshold
	# Swap the rule for a looser one mid-game.
	ruleset.remove_named(&"extra_turn")
	var loose := ExtraTurnRule.new()
	loose.min_match = 3
	ruleset.add(loose)
	var ctx2 := MatchRuleContext.new()
	ctx2.max_run = 4
	ruleset.run(MatchPhase.MOVE_RESOLVED, ctx2)
	assert_bool(ctx2.go_again).is_true()  # now the same 4-run qualifies


# A grant rule banks matched tiles straight into the mover's tally — the migrated default "a match of N is
# worth N" (one-to-one with no scoring formula), now a unit-testable rule with no scene.
func test_resource_grant_rule_banks_matched_tiles() -> void:
	var enc := _encounter()
	var match_context := MatchRuleContext.new()
	match_context.encounter = enc
	match_context.combatant = enc.player
	var counts: Dictionary[int, int] = {}
	counts[_COMBAT_KIND] = 4
	match_context.counts = counts
	var centers: Dictionary[int, Vector2] = {}
	centers[_COMBAT_KIND] = Vector2.ZERO
	match_context.centers = centers
	ResourceGrantRule.new().apply(match_context)
	assert_int(enc.player.resource_of(_resource(_COMBAT_KIND))).is_equal(4)
	assert_int(match_context.visuals.size()).is_equal(1)


# The authored default ruleset carries the grant rules, so a default match already banks resources.
func test_default_rules_include_baseline_grants() -> void:
	var ruleset := RuleCatalog.default_ruleset()
	assert_object(ruleset.find(&"resource_grant")).is_not_null()
	assert_object(ruleset.find(&"damage")).is_not_null()
	assert_object(ruleset.find(&"warp")).is_not_null()
	assert_object(ruleset.find(&"scrap_grant")).is_not_null()


# --- Tunable knobs: capacity, scoring offset, action budget ---


# The turn-start knobs ride in the default ruleset at their no-op defaults, so the default match plays exactly
# as before: one action a turn (an ability ends it), unlimited resources, one-to-one scoring.
func test_default_rules_include_turn_start_knobs_at_parity() -> void:
	var ruleset := RuleCatalog.default_ruleset()
	var budget := ruleset.find(&"action_budget") as ActionBudgetRule
	assert_object(budget).is_not_null()
	assert_int(budget.actions_per_turn).is_equal(1)
	assert_int(budget.ability_turn_cost).is_equal(ActionBudgetRule.AbilityTurnCost.ENDS_TURN)
	var offset := ruleset.find(&"scoring_offset") as OffsetScoringRule
	assert_object(offset).is_not_null()
	assert_int(offset.offset).is_equal(0)
	var capacity := ruleset.find(&"resource_capacity") as ResourceCapacityRule
	assert_object(capacity).is_not_null()
	assert_bool(capacity.maximums.is_empty()).is_true()


# The scoring offset shifts every match's reward down by its amount, floored at zero (3→1, 7→5); zero leaves
# scoring one-to-one.
func test_scoring_offset_reduces_reward() -> void:
	var match_context := MatchRuleContext.new()
	assert_int(match_context.reward_for(3)).is_equal(3)  # no offset → one-to-one
	match_context.score_offset = 2
	assert_int(match_context.reward_for(3)).is_equal(1)
	assert_int(match_context.reward_for(7)).is_equal(5)
	assert_int(match_context.reward_for(1)).is_equal(0)  # never negative


# The OffsetScoringRule writes its offset onto the mover at turn start; with it in force a 4-match banks 4 - 2.
func test_offset_scoring_rule_banks_reduced_reward() -> void:
	var enc := _encounter()
	var rule := OffsetScoringRule.new()
	rule.offset = 2
	var turn_ctx := MatchRuleContext.new()
	turn_ctx.encounter = enc
	turn_ctx.combatant = enc.player
	rule.apply(turn_ctx)
	assert_int(enc.player.score_offset).is_equal(2)
	var clear_ctx := MatchRuleContext.new()
	clear_ctx.encounter = enc
	clear_ctx.combatant = enc.player
	clear_ctx.score_offset = 2
	var counts: Dictionary[int, int] = {}
	counts[_COMBAT_KIND] = 4
	clear_ctx.counts = counts
	var centers: Dictionary[int, Vector2] = {}
	centers[_COMBAT_KIND] = Vector2.ZERO
	clear_ctx.centers = centers
	ResourceGrantRule.new().apply(clear_ctx)
	assert_int(enc.player.resource_of(_resource(_COMBAT_KIND))).is_equal(2)


# Resource capacity clamps banking: with a maximum set a starship never holds more than it (and any surplus already
# banked is clamped down); a zero maximum is unlimited.
func test_resource_capacity_clamps_banking() -> void:
	var starship := Combatant.new()
	starship.add_resource(_resource(_COMBAT_KIND), 100)
	assert_int(starship.resource_of(_resource(_COMBAT_KIND))).is_equal(100)  # unlimited by default
	starship.set_resource_maximums(PackedInt32Array([5, 0, 0, 0, 0, 0, 0]))
	assert_int(starship.resource_of(_resource(_COMBAT_KIND))).is_equal(5)  # already-banked clamped to the new ceiling
	starship.add_resource(_resource(_COMBAT_KIND), 10)
	assert_int(starship.resource_of(_resource(_COMBAT_KIND))).is_equal(5)  # banking can't exceed it
	starship.add_resource(_resource(1), 10)
	assert_int(starship.resource_of(_resource(1))).is_equal(10)  # an uncapped kind stays unlimited


# The ResourceCapacityRule writes the maximums onto the mover at turn start.
func test_resource_capacity_rule_sets_mover_maximums() -> void:
	var enc := _encounter()
	var rule := ResourceCapacityRule.new()
	rule.maximums = PackedInt32Array([7, 0, 0, 0, 0, 0, 0])
	var match_context := MatchRuleContext.new()
	match_context.encounter = enc
	match_context.combatant = enc.player
	rule.apply(match_context)
	var starship := enc.player
	starship.add_resource(_resource(_COMBAT_KIND), 100)
	assert_int(starship.resource_of(_resource(_COMBAT_KIND))).is_equal(7)


# The ActionBudgetRule refills the mover's actions at turn start to its actions-per-turn (and sets the policy).
func test_action_budget_rule_refills_actions() -> void:
	var enc := _encounter()
	var rule := ActionBudgetRule.new()
	rule.actions_per_turn = 4
	rule.ability_turn_cost = ActionBudgetRule.AbilityTurnCost.COSTS_ACTION
	var match_context := MatchRuleContext.new()
	match_context.encounter = enc
	match_context.combatant = enc.player
	rule.apply(match_context)
	var starship := enc.player
	assert_int(starship.actions_remaining).is_equal(4)
	assert_int(starship.ability_turn_cost).is_equal(ActionBudgetRule.AbilityTurnCost.COSTS_ACTION)


# The action budget gates moves per turn: with three actions a mover keeps the board for three resolved moves,
# the turn passing on the third. (The default one-action budget passes on the first move — unchanged.)
func test_action_budget_gates_moves_per_turn() -> void:
	var game := _make(RuleCatalog.default_ruleset(), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	game._encounter.player.actions_remaining = 3
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)
	game._on_move_resolved(true, 1)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)  # 2 left
	game._on_move_resolved(true, 1)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)  # 1 left
	game._on_move_resolved(true, 1)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.opponent)  # spent → passes
	game.queue_free()


# With the COSTS_ACTION policy an ability spends one action instead of ending the turn, so a mover with budget
# to spare keeps acting; the turn passes only once the budget is gone.
func test_ability_costs_an_action_when_policy_set() -> void:
	var game := _make(RuleCatalog.default_ruleset(), MatchBoardView.InputMode.LINE_SHIFT, false)
	await await_idle_frame()
	game._encounter.player.resources[_COMBAT_KIND].amount = 100
	game._encounter.player.actions_remaining = 2
	game._encounter.player.ability_turn_cost = ActionBudgetRule.AbilityTurnCost.COSTS_ACTION
	var ability := MatchAbilities.attack("Test", _resource(_COMBAT_KIND), 5, 1)
	game._use_ability(game._encounter.player, ability)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.player)  # one action left
	game._use_ability(game._encounter.player, ability)
	assert_object(game._encounter.active_combatant()).is_same(game._encounter.opponent)  # spent → passes
	game.queue_free()


# The authored alternate-mode resource is a real Ruleset: it dials the same knobs to a low-mana, multi-action
# turn (a match of N banks N-2, four moves a turn) without any code — the "make a new mode resource" path.
func test_alternate_mode_resource_dials_the_knobs() -> void:
	var path := "res://data/rulesets/alternate.tres"
	assert_bool(ResourceLoader.exists(path)).is_true()
	var ruleset: Ruleset = load(path)
	assert_object(ruleset).is_not_null()
	assert_int((ruleset.find(&"scoring_offset") as OffsetScoringRule).offset).is_equal(2)
	assert_int((ruleset.find(&"action_budget") as ActionBudgetRule).actions_per_turn).is_equal(4)


# A TURN_START rule fires when the turn hands over — the hook a "rotate the board each turn" rule would use.
func test_turn_start_phase_fires_on_handover() -> void:
	var spy := _PhaseSpy.new()
	spy.phase = MatchPhase.TURN_START
	var ruleset := Ruleset.new()
	ruleset.add(spy)
	var game := _make(ruleset, MatchBoardView.InputMode.SWAP, false)
	await await_idle_frame()
	var before: int = spy.fired
	game._advance_turn()
	assert_int(spy.fired).is_equal(before + 1)
	game.queue_free()


# A VICTORY rule fires once when a combatant falls — the hook an end-of-fight effect would use.
func test_victory_phase_fires_on_end() -> void:
	var spy := _PhaseSpy.new()
	spy.phase = MatchPhase.VICTORY
	var ruleset := Ruleset.new()
	ruleset.add(spy)
	var game := _make(ruleset, MatchBoardView.InputMode.SWAP, false)
	await await_idle_frame()
	game._encounter.opponent_health = 0  # opponent down → the player wins
	game._check_for_end()
	assert_int(spy.fired).is_equal(1)
	game.queue_free()


# --- Selection rules ---


# Each SelectionRule mode maps to the engine input mode that drives it.
func test_selection_rule_maps_to_engine_modes() -> void:
	assert_int(SelectionRule.make(SelectionRule.Mode.SWAP).input_mode()).is_equal(MatchBoardView.InputMode.SWAP)
	assert_int(SelectionRule.make(SelectionRule.Mode.SLIDE).input_mode()).is_equal(MatchBoardView.InputMode.LINE_SHIFT)
	assert_int(SelectionRule.make(SelectionRule.Mode.TRACE).input_mode()).is_equal(MatchBoardView.InputMode.CONNECT)
	assert_int(SelectionRule.make(SelectionRule.Mode.TELEPORT).input_mode()).is_equal(MatchBoardView.InputMode.TELEPORT)


# A starship's selection override takes over the board on its turn, then the board reverts when the turn
# passes back to a starship without one — the Fluxx-style "selection changes with whoever is acting".
func test_starship_override_switches_selection_on_its_turn() -> void:
	var game := _make(null, MatchBoardView.InputMode.SWAP, false)  # hot-seat, so no AI auto-play interferes
	await await_idle_frame()
	# The player has no override → the board plays by the SWAP fallback.
	assert_int(game.input_mode).is_equal(MatchBoardView.InputMode.SWAP)
	# Force a TRACE selection on the opponent; its turn switches the board to it.
	game._encounter.opponent.starship.selection_override = SelectionRule.make(SelectionRule.Mode.TRACE)
	game._encounter.advance_turn()  # → opponent
	game._refresh_turn_tracker()
	assert_int(game.input_mode).is_equal(MatchBoardView.InputMode.CONNECT)
	# Back to the player → reverts to the default SWAP.
	game._encounter.advance_turn()  # → player
	game._refresh_turn_tracker()
	assert_int(game.input_mode).is_equal(MatchBoardView.InputMode.SWAP)
	game.queue_free()


const _KIND_IDS := {"R": 0, "G": 1, "B": 2, "Y": 3}


# Builds a single-layer GridState from a row-major string of kind letters
# (index 0 is cell (0, 0), filling left-to-right then top-to-bottom).
func _board(width: int, height: int, kinds: String) -> GridState:
	var state := GridState.new(width, height, 1)
	for i: int in kinds.length():
		var cells: Array[Vector2i] = [Vector2i(i % width, i / width)]
		state.place_object(0, GridObjectState.new(cells, {"kind": _KIND_IDS[kinds[i]]}))
	return state


# Whether swapping the two cells' kinds forms a match at either — mirrors the
# solver's own gate, used to re-validate the move it picked.
func _swap_makes_match(state: GridState, condition: MatchLineCondition, a: Vector2i, b: Vector2i) -> bool:
	var object_a: GridObjectState = state.get_object_at(0, a.x, a.y)
	var object_b: GridObjectState = state.get_object_at(0, b.x, b.y)
	var kind_a: Variant = object_a.state.get("kind")
	var kind_b: Variant = object_b.state.get("kind")
	object_a.state["kind"] = kind_b
	object_b.state["kind"] = kind_a
	var matches: Array[Vector2i] = condition.find_matches(state)
	object_a.state["kind"] = kind_a
	object_b.state["kind"] = kind_b
	return matches.has(a) or matches.has(b)


# A throwaway rule that counts how often it fires — used to assert a lifecycle phase actually reaches rules.
class _PhaseSpy:
	extends Rule
	var fired: int = 0

	func apply(_context: RuleContext) -> void:
		fired += 1
