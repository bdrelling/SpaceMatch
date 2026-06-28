extends GdUnitTestSuite
## BoardFillRule / TerritoryRule as composable [Rule]s: their direction/colour mapping, and that a ship's
## rule overrides the match default through the same name-based composition [method MatchMinigame._effective_ruleset]
## uses — the guarantee that fill and territory plug into the one ruleset system rather than a parallel track.

# Mirrors MatchMinigame._effective_ruleset: match rules first, then ship rules layered over, a same-named ship
# rule replacing the match's. This is the exact composition the host runs each turn.
func _compose(match_rules: Array[Rule], ship_rules: Array[Rule]) -> Ruleset:
	var composed := Ruleset.new()
	for rule: Rule in match_rules:
		composed.add(rule)
	for rule: Rule in ship_rules:
		if rule.rule_name != &"":
			composed.remove_named(rule.rule_name)
		composed.add(rule)
	return composed

func _active_fill(ruleset: Ruleset) -> BoardFillRule:
	var found: BoardFillRule = null
	for rule: Rule in ruleset.rules:
		if rule is BoardFillRule and rule.enabled:
			found = rule
	return found

func test_direction_vector_maps_each_edge() -> void:
	assert_vector(BoardFillRule.make(BoardFillRule.Direction.TOP).direction_vector()).is_equal(Vector2i(0, 1))
	assert_vector(BoardFillRule.make(BoardFillRule.Direction.BOTTOM).direction_vector()).is_equal(Vector2i(0, -1))
	assert_vector(BoardFillRule.make(BoardFillRule.Direction.LEFT).direction_vector()).is_equal(Vector2i(1, 0))
	assert_vector(BoardFillRule.make(BoardFillRule.Direction.RIGHT).direction_vector()).is_equal(Vector2i(-1, 0))

func test_defaults_to_top_down() -> void:
	assert_vector(BoardFillRule.new().direction_vector()).is_equal(Vector2i(0, 1))

func test_default_ruleset_carries_a_fill_rule() -> void:
	# The board-fill rule rides in the authored default ruleset, so every match has one to override (top-down).
	var fill: BoardFillRule = _active_fill(RuleCatalog.default_ruleset())
	assert_object(fill).is_not_null()
	assert_vector(fill.direction_vector()).is_equal(Vector2i(0, 1))

func test_ship_fill_rule_overrides_match_default_by_name() -> void:
	# Match default fills top-down; a ship brings its own board_fill — composition replaces by name, so the
	# ship's direction wins on its turn. This is "each side fills from its own edge" with zero special-casing.
	var match_rules: Array[Rule] = [BoardFillRule.make(BoardFillRule.Direction.TOP)]
	var ship_rules: Array[Rule] = [BoardFillRule.make(BoardFillRule.Direction.BOTTOM)]
	var composed: Ruleset = _compose(match_rules, ship_rules)
	# Exactly one board_fill survives (no duplicate), and it's the ship's.
	var fills: int = 0
	for rule: Rule in composed.rules:
		if rule is BoardFillRule:
			fills += 1
	assert_int(fills).is_equal(1)
	assert_vector(_active_fill(composed).direction_vector()).is_equal(Vector2i(0, -1))

func test_territory_rule_colours_by_side() -> void:
	var territory := TerritoryRule.new()
	assert_bool(territory.color_for(EncounterState.Combatant.PLAYER) == territory.player_color).is_true()
	assert_bool(territory.color_for(EncounterState.Combatant.OPPONENT) == territory.opponent_color).is_true()
	# Neutral / unowned tiles get a transparent (undrawn) ring.
	assert_float(territory.color_for(-1).a).is_equal(0.0)
