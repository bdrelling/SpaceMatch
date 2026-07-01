class_name MatchBoardFactory
extends RefCounted
## Pure board generation and measurement for the match: generates the starting board, picks weighted tile kinds
## for refills, and sizes a cleared match. Every method is static and takes what it needs as a parameter (the
## board, the RNG, the composed spawn table, the input knobs) so it holds no state and reaches nothing — the
## [MatchGame] coordinator wires it into the session's generator / tile callbacks and hands it the live values.

#region Methods


# Builds the [GridSession] from a [MatchBlueprint] seeded off the board config / knobs, wiring [param generate_cb]
# as its generator. The verbs (swap, slide, teleport, connect) all live in the blueprint; the selection engine
# flips which one is live per turn.
# The how-to-play status line for the active input mode.
static func prompt_for_mode(input_mode: MatchBoardView.InputMode, min_run: int) -> String:
	match input_mode:
		MatchBoardView.InputMode.CONNECT:
			return "Trace through %d+ matching tiles to clear them." % min_run
		MatchBoardView.InputMode.LINE_SHIFT:
			return "Slide a tile along a row or column to match %d." % min_run
		MatchBoardView.InputMode.TELEPORT:
			return "Tap a tile, then another, to swap them and match %d." % min_run
		_:
			return "Match %d in a row to clear." % min_run


static func build_session(config: MatchConfig, seed: int, input_mode: MatchBoardView.InputMode, allow_diagonal: bool, generate_cb: Callable) -> GridSession:
	var blueprint := MatchBlueprint.new()
	blueprint.rng_seed = seed
	blueprint.input_mode = input_mode
	blueprint.allow_diagonal = allow_diagonal
	blueprint.board_width = config.board_width
	blueprint.board_height = config.board_height
	blueprint.min_run = config.min_run
	blueprint.build()
	var session := GridSession.create(blueprint)
	session.generator = CallableGridGenerator.create(generate_cb)
	return session


# Every board tile kind, from the resource catalog (each StarshipResource's id). Reads the live catalog, so
# adding a resource in-editor adds its kind here automatically.
static func tile_kinds() -> Array[int]:
	return Catalogs.ability_resources.tile_kinds()


# The board's spawn pool: every SpawnResourceRule's weight in [param source], composed, with warp forced off
# unless warp is actually in play — so a starship that can't warp never rolls a warp tile. [param source] is the
# effective ruleset the caller composed against whoever is filling now.
static func spawn_table(source: Ruleset, warp_active: bool, warp_kind: int) -> Dictionary:
	var table: Dictionary = source.aggregate(&"spawn_contribution") if source != null else {}
	if not warp_active:
		table[warp_kind] = 0
	return table


# A weighted kind for a refill — the board is a generator, so it can't stall and a refill may roll a fresh
# match (the cascades). Weights come from [param spawn_table].
static func pick_kind(rng: RandomNumberGenerator, table: Dictionary) -> int:
	return weighted_choice(tile_kinds(), rng, table)


# A kind for cell (x, y) that doesn't complete a 3-run there, so a freshly generated board starts stable;
# weighted (per [param table]) among the safe kinds.
static func pick_kind_avoiding_runs(state: GridState, x: int, y: int, rng: RandomNumberGenerator, table: Dictionary) -> int:
	var safe: Array[int] = []
	for kind: int in tile_kinds():
		if not would_complete_run(state, x, y, kind):
			safe.append(kind)
	if safe.is_empty():
		return pick_kind(rng, table)
	return weighted_choice(safe, rng, table)


# Roulette-wheel pick over [param candidates], each kind weighted by [param table] and drawn from the board's
# seeded [param rng] so generation stays reproducible. Falls back to a uniform pick when the candidates carry
# no weight at all.
static func weighted_choice(candidates: Array[int], rng: RandomNumberGenerator, table: Dictionary) -> int:
	var total: int = 0
	for kind: int in candidates:
		var weight: int = table.get(kind, 0)
		total += weight
	if total <= 0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll: int = rng.randi_range(0, total - 1)
	for kind: int in candidates:
		var weight: int = table.get(kind, 0)
		roll -= weight
		if roll < 0:
			return kind
	return candidates[candidates.size() - 1]


static func would_complete_run(state: GridState, x: int, y: int, kind: int) -> bool:
	if x >= 2 and kind_at(state, x - 1, y) == kind and kind_at(state, x - 2, y) == kind:
		return true
	if y >= 2 and kind_at(state, x, y - 1) == kind and kind_at(state, x, y - 2) == kind:
		return true
	return false


static func kind_at(state: GridState, x: int, y: int) -> int:
	var tile := state.get_object_at(0, x, y) as MatchTileState
	if tile == null:
		return -1
	return tile.kind


# The one way a match's size is measured anywhere — extra turns, warp, all of it — so the shape rules are
# identical for every tile, never per type. How a match is sized depends only on how it was cleared, never on
# re-reading the board, because the same cells can be two different matches:
#   - is_path (a drag/trace clear): the traced path IS the match, so its size is the whole run of cells.
#   - line clears (swap / slide, and every cascade): a match is a straight run of [param min_run]+; runs that
#     share a cell merge into one match; size is the distinct cells in the largest merged group. So an L
#     (3+3 sharing a corner) is 5 and a T (4+3) is 6, while a 3x2 block — two parallel runs sharing no cell —
#     stays two 3s, never a 6 (which a blind flood-fill would wrongly merge). Diagonal runs count only when the
#     active rule matches along them ([param allow_diagonal]).
# A 3x2 dragged whole is a 6; the same 3x2 swapped into place is a 3 — that's the whole reason for is_path.
static func largest_match(board: GridState, cells: Array[Vector2i], is_path: bool, allow_diagonal: bool, min_run: int) -> int:
	if cells.is_empty():
		return 0
	if is_path:
		return cells.size()
	var kinds: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in cells:
		kinds[cell] = kind_at(board, cell.x, cell.y)
	var axes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	if allow_diagonal:
		axes.append(Vector2i(1, 1))
		axes.append(Vector2i(1, -1))
	# Union the members of every run >= min_run; a cell shared by a row and a column run links them into one
	# match. A cell in no qualifying run stays a singleton, so parallel runs (a 3x2) never merge.
	var parent: Dictionary[Vector2i, Vector2i] = {}
	for cell: Vector2i in cells:
		parent[cell] = cell
	for axis: Vector2i in axes:
		for cell: Vector2i in cells:
			var kind: int = kinds[cell]
			if kinds.get(cell - axis, -1) == kind:
				continue  # measure each run once, from its head (no same-kind predecessor along the axis)
			var run: Array[Vector2i] = [cell]
			var probe: Vector2i = cell + axis
			while kinds.get(probe, -1) == kind:
				run.append(probe)
				probe += axis
			if run.size() < min_run:
				continue
			for index: int in range(1, run.size()):
				union_cells(parent, run[0], run[index])
	var sizes: Dictionary[Vector2i, int] = {}
	var best: int = 1
	for cell: Vector2i in cells:
		var root: Vector2i = find_cell(parent, cell)
		sizes[root] = sizes.get(root, 0) + 1
		best = maxi(best, sizes[root])
	return best


static func find_cell(parent: Dictionary[Vector2i, Vector2i], cell: Vector2i) -> Vector2i:
	var root: Vector2i = cell
	while parent[root] != root:
		root = parent[root]
	return root


static func union_cells(parent: Dictionary[Vector2i, Vector2i], a: Vector2i, b: Vector2i) -> void:
	var root_a: Vector2i = find_cell(parent, a)
	var root_b: Vector2i = find_cell(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a


# The owner marker a freshly refilled tile belongs to: whoever is clearing now drives the refill, so new tiles
# enter owned by the active side. The marker is the active combatant's [member Entity.id] (0 player, 1 opponent).
# Neutral (-1) with no encounter — the standalone board has no sides.
static func refill_owner(encounter: EncounterState) -> int:
	var active: Combatant = encounter.active_combatant() if encounter != null else null
	return active.id if active != null else -1


# The outline tint marking which side owns a tile, from the active [TerritoryRule] (which carries the team
# colours). Transparent — no ring — for neutral tiles or any match without a territory rule.
static func owner_color(owner: int, territory: TerritoryRule) -> Color:
	return territory.color_for(owner) if territory != null else Color(0, 0, 0, 0)


# Builds the starting board: a fresh single-layer [GridState] filled with run-avoiding tiles, seeded off the
# session so it is reproducible. [param table] is the composed spawn pool for generation.
static func generate_board(config: MatchConfig, rng: RandomNumberGenerator, session: GridSession, table: Dictionary) -> GridState:
	var state := GridState.new(config.board_width, config.board_height, 1)
	# One stream feeds generation and refills.
	rng.seed = session.derive_seed("tiles")
	for y: int in config.board_height:
		for x: int in config.board_width:
			var cells: Array[Vector2i] = [Vector2i(x, y)]
			state.place_object(0, MatchTileState.new(cells, pick_kind_avoiding_runs(state, x, y, rng, table)))
	return state

#endregion
