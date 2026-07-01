extends MatchTestCase
## Scoring formulas, reload split, and unaffordable abilities.


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
