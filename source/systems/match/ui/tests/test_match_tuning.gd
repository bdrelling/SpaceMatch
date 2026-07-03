extends MatchTestCase
## Tunable knobs: scoring offset, resource capacity, and action budget.


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
	var grant := TileMatchRule.new()
	grant.tile = Catalogs.tiles.for_kind(_COMBAT_KIND)
	grant.reward = _resource(_COMBAT_KIND)
	grant.apply(clear_ctx)
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
