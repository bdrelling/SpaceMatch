extends MatchTestCase
## Shield, dodge, and damage combat state through the effect engine.


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
