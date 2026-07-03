extends MatchTestCase
## Rule/Ruleset engine: phase gating, enable/disable, swapping, and grant rules.


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


# A tile-match rule banks matched tiles straight into the mover's tally — the "a match of N is worth N"
# (one-to-one with no scoring formula), now a unit-testable rule with no scene.
func test_tile_match_rule_banks_matched_tiles() -> void:
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
	var rule := TileMatchRule.new()
	rule.tile = Catalogs.tiles.for_kind(_COMBAT_KIND)
	rule.reward = _resource(_COMBAT_KIND)
	rule.apply(match_context)
	assert_int(enc.player.resource_of(_resource(_COMBAT_KIND))).is_equal(4)
	assert_int(match_context.visuals.size()).is_equal(1)


# The authored default ruleset carries the grant rules, so a default match already banks resources.
func test_default_rules_include_baseline_grants() -> void:
	var ruleset := RuleCatalog.default_ruleset()
	assert_object(ruleset.find(&"tile_match")).is_not_null()
	assert_object(ruleset.find(&"damage")).is_not_null()
	assert_object(ruleset.find(&"warp")).is_not_null()
	assert_object(ruleset.find(&"scrap_grant")).is_not_null()
