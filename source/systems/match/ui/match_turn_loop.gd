class_name MatchTurnLoop
extends RefCounted
## The input gate and the AI opponent's turn: decides when the human may touch the board, and drives the computer
## opponent — think for a beat, spend an affordable ability or solve a swap, else pass. Reads the board and the
## encounter through the shared [MatchContext]; the coordinator hands it the live flags / exports and the flow
## callbacks (use-ability, advance-turn) it must invoke, so it never holds the coordinator.

#region Properties

var _ctx: MatchContext

#endregion

#region Methods


func _init(ctx: MatchContext) -> void:
	_ctx = ctx


# Whether the human may act now: not game-over, not mid-resolve, and — when the AI controls the opponent — only
# on the player's own turn (so the player can't move on the AI's behalf).
func accepts_player_input(game_over: bool, resolving: bool, ai_opponent: bool) -> bool:
	if game_over or resolving:
		return false
	if _ctx.encounter == null or not ai_opponent:
		return true
	return _ctx.encounter.active_combatant() == _ctx.encounter.player


# When the turn has passed to the AI opponent, think for a beat, then play the best move the solver can find.
# Fire-and-forget: the resulting move re-enters the coordinator's move-resolved flow, which hands the turn back.
# The coordinator passes the live flags / exports plus the use-ability and advance-turn callbacks.
# gdlint:disable=max-returns
func take_opponent_turn_if_needed(
	game_over: bool, ai_opponent: bool, move_delay: float, gravity: MatchGravity, use_ability: Callable, advance_turn: Callable
) -> void:
	if game_over or not ai_opponent or _ctx.match_view == null:
		return
	if _ctx.encounter == null or _ctx.encounter.active_combatant() != _ctx.encounter.opponent:
		return
	if move_delay > 0.0:
		await _ctx.match_view.get_tree().create_timer(move_delay).timeout
	# The board may have torn down (e.g. screen left) during the think beat — bail before touching it.
	if not _ctx.match_view.is_inside_tree() or _ctx.encounter == null:
		return
	# State can shift during the think beat (e.g. gravity unlocked) — re-check before moving.
	if _ctx.encounter.active_combatant() != _ctx.encounter.opponent:
		return
	if gravity != null and gravity.is_active():
		return
	# Spend tiles on an attack when it can afford one — an ability ends the turn, so it's played instead of a board
	# move (and works in any selection mode, since it's not a board move).
	var ability: Ability = MatchAbilityBar.best_affordable_ability(
		_ctx.encounter, _ctx.rules.starship_abilities(_ctx.encounter.opponent), _ctx.encounter.opponent
	)
	if ability != null:
		use_ability.call(_ctx.encounter.opponent, ability)
		return
	# The AI can only solve swaps for now. On any other selection mode (the opponent's starship forced slide /
	# trace / teleport), report the gap loudly and pass rather than soft-lock — build the matching solver (mirror
	# SwapSolver for that interaction) when an opponent needs to play it.
	if _ctx.input_mode != MatchBoardView.InputMode.SWAP:
		var mode_name: String = MatchBoardView.InputMode.keys()[_ctx.input_mode]
		push_error("MatchGame: AI opponent has no solver for %s yet — not implemented." % mode_name)
		_ctx.set_status.call("Opponent can't play %s yet — passing." % mode_name.to_lower())
		pass_opponent_turn(advance_turn)
		return
	var swap := _ctx.session.find_interaction(GridInteraction.Gesture.SWIPE) as SwapInteraction
	var move: Array[Vector2i] = SwapSolver.best_move(_ctx.session.state, swap)
	if move.is_empty():
		pass_opponent_turn(advance_turn)
		return
	await _ctx.match_view.perform_move(move)


# gdlint:enable=max-returns


# A dead board (no swap makes a match) — skip the opponent's move so play doesn't stall, handing the turn straight
# back to the player. [param advance_turn] is the coordinator's turn handover.
func pass_opponent_turn(advance_turn: Callable) -> void:
	var passer: String = _active_name()
	if _ctx.encounter != null:
		advance_turn.call()
	_ctx.set_status.call("%s has no move — %s's turn." % [passer, _active_name()])


# The display name of the combatant whose turn it currently is.
func _active_name() -> String:
	if _ctx.encounter == null:
		return _ctx.player_portrait.portrait_name
	return _ctx.opponent_portrait.portrait_name if _ctx.encounter.active_combatant() == _ctx.encounter.opponent else _ctx.player_portrait.portrait_name

#endregion
