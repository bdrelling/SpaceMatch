class_name MatchTestCase
extends GdUnitTestSuite
## Shared fixtures for the match suites: before_test setup, the _make/_encounter builders,
## the tile-kind constants, and the board/buff/resource helpers. Holds no test_ methods, so
## gdUnit4 skips it as a suite.

#region Constants
# Combat (kind 0) is a stat readout, so its number includes the matched-tile tally.
const _COMBAT_KIND: int = 0
const _SCRAP_KIND: int = 4
const _WARP_KIND: int = 5
const _DAMAGE_KIND: int = 6

const _KIND_IDS := {"R": 0, "G": 1, "B": 2, "Y": 3}
#endregion


#region Methods
# Reset the shared GameSession singleton before each test so a fresh default game (starship + wallet) backs the
# run and tests don't leak state into each other.
func before_test() -> void:
	GameSession.start_new_game()


# A standalone encounter with default combatant starships, freed at test end. GameCoordinator builds the two
# [Starship] nodes; tests operate on its [EncounterState] directly (resources, no node-reaching).
func _encounter() -> EncounterState:
	var encounter: Encounter = auto_free(GameCoordinator.start_quick_match())
	return encounter.state


# Acts as a host mounting the match: opens an encounter on the session (a clone of the player starship vs the
# computer default) and binds the match to it, the way [Game] / [EncounterScreen] do.
func _host_bind(game: MatchGame) -> void:
	auto_free(GameCoordinator.start_quick_match())
	game.bind_session()


func _make(ruleset: Ruleset = null, mode := MatchBoardView.InputMode.SWAP, ai := true) -> MatchGame:
	var scene: PackedScene = load("res://systems/match/ui/match_game.tscn")
	var game: MatchGame = scene.instantiate()
	game.board_seed = 4242
	game.input_mode = mode
	# Insulate the existing behaviour tests from the spawn weights and extra-turn rule: a neutral
	# ruleset (no extra turns, uniform spawn) unless a test asks for a specific one.
	game.ruleset = ruleset if ruleset != null else RuleCatalog.default_ruleset()
	# Resolve actions instantly in tests so an ability's turn-handover isn't gated behind an animation beat.
	game.action_resolve_delay = 0.0
	# Most turn/ability tests isolate the logic from the AI opponent — a hot-seat opponent never auto-plays.
	game.ai_opponent = ai
	add_child(game)
	# Behaviour tests run on neutral rules: clear each fight starship's own ruleset (its extra-turn kit) so a 4+
	# match doesn't silently keep the board. Abilities stay — the AI ability tests read the starship's set.
	if game._encounter != null:
		if game._encounter.player != null:
			game._encounter.player.starship.ruleset = Ruleset.new()
		if game._encounter.opponent != null:
			game._encounter.opponent.starship.ruleset = Ruleset.new()
	return game


# Applies `amount` to `stat_name` on a combatant as a status-backed stat modifier (a unit-amount [Modifier]
# stacked `amount` times) — the test stand-in for an authored buff/debuff status.
func _buff(enc: EncounterState, combatant: Combatant, stat_name: StringName, amount: int) -> void:
	var status := Status.new()
	status.name = stat_name
	var stat := StarshipStat.new()
	stat.name = stat_name
	var modifier := Modifier.new()
	modifier.stat = stat
	modifier.operation = Modifier.Operation.ADD
	modifier.amount = 1.0
	status.modifiers.append(modifier)
	enc.add_status(combatant, status, amount)


# The [StarshipResource] backing a board tile kind — the type the resource/ability API now references. Looked
# up through the live catalog so a test reads exactly what the game banks.
func _resource(tile_kind: int) -> StarshipResource:
	return Catalogs.ability_resources.for_tile(tile_kind)


# Overwrites the kind of each given cell's tile in place — for building a known run to measure.
func _force_kind(board: GridState, cells: Array[Vector2i], kind: int) -> void:
	for cell: Vector2i in cells:
		var tile: GridObjectState = board.get_object_at(0, cell.x, cell.y)
		tile.set("kind", kind)
		tile.state["kind"] = kind


# A Ruleset carrying a single ExtraTurnRule — the migrated form of the old flat knob.
func _extra_turn_rules(min_match: int) -> Ruleset:
	var ruleset := Ruleset.new()
	var rule := ExtraTurnRule.new()
	rule.min_match = min_match
	ruleset.add(rule)
	return ruleset


# Builds a single-layer GridState from a row-major string of kind letters
# (index 0 is cell (0, 0), filling left-to-right then top-to-bottom).
func _board(width: int, height: int, kinds: String) -> GridState:
	var state := GridState.new(width, height, 1)
	for i: int in kinds.length():
		var cells: Array[Vector2i] = [Vector2i(i % width, i / width)]
		state.place_object(0, GridObjectState.new(cells, {"kind": _KIND_IDS[kinds[i]]}))
	return state


# Whether swapping the two cells' kinds forms a match at either — mirrors the
# solver's own gate, used to re-validate the move it picked.
func _swap_makes_match(state: GridState, condition: MatchLineCondition, a: Vector2i, b: Vector2i) -> bool:
	var object_a: GridObjectState = state.get_object_at(0, a.x, a.y)
	var object_b: GridObjectState = state.get_object_at(0, b.x, b.y)
	var kind_a: Variant = object_a.state.get("kind")
	var kind_b: Variant = object_b.state.get("kind")
	object_a.state["kind"] = kind_b
	object_b.state["kind"] = kind_a
	var matches: Array[Vector2i] = condition.find_matches(state)
	object_a.state["kind"] = kind_a
	object_b.state["kind"] = kind_b
	return matches.has(a) or matches.has(b)
#endregion
