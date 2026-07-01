extends MatchTestCase
## Ability effects: shields, target lock, siphon, disruptor, and disabled cells.


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
	game._encounter.disabled.disable(true, Vector2i(2, 4), 3)
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
	assert_int(game._encounter.disabled.cells_of(false).size()).is_equal(0)
	game._use_ability(game._encounter.player, disrupt)
	var disabled: Array[Vector2i] = game._encounter.disabled.cells_of(false)
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
	enc.disabled.disable(false, Vector2i(2, 0), 3)
	assert_array(enc.disabled.cells_of(false)).contains([Vector2i(2, 0)])
	enc.advance_turn()  # 3 -> 2
	enc.advance_turn()  # 2 -> 1
	assert_int(enc.disabled.cells_of(false).size()).is_equal(1)
	enc.advance_turn()  # 1 -> 0, re-enabled
	assert_int(enc.disabled.cells_of(false).size()).is_equal(0)
	assert_int(enc.disabled.cells_of(true).size()).is_equal(0)
