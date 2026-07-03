extends MatchTestCase
## Default match config and the starship-based extra-turn rule.


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
	# Spawn weights live on per-tile TileSpawnRules (the nested Spawn set), composed into one pool —
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
