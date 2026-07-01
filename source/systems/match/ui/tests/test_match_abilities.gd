extends MatchTestCase
## Ability definitions and the AI opponent's ability choices.


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
