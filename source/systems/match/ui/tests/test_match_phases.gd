extends MatchTestCase
## Lifecycle phases (turn-start, victory) and selection-rule mode switching.


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


# A throwaway rule that counts how often it fires — used to assert a lifecycle phase actually reaches rules.
class _PhaseSpy:
	extends Rule
	var fired: int = 0

	func apply(_context: RuleContext) -> void:
		fired += 1
