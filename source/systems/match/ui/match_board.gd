class_name MatchBoard
extends RefCounted
## Board spawning and sizing for the match: the tile callbacks the session drives (make / spawn / generate) and
## the kind / match-size queries, each threading the live [MatchContext] (its rng, rules, readouts and encounter)
## into the context-free [MatchBoardFactory] so that factory stays pure. Held on [member MatchContext.board].

#region Constants
## Warp (kind 5) — the one tile kind named here, to gate it out of the spawn table when warp isn't in play.
const WARP_KIND: int = 5
#endregion

#region Properties
var _ctx: MatchContext
#endregion


#region Methods
func _init(ctx: MatchContext) -> void:
	_ctx = ctx


## The board tile node for [param object] — its kind, plus a territory outline when a shared board tags ownership.
func make_tile(object: GridObjectState) -> Node2D:
	var tile := MatchTile.new()
	var tile_state := object as MatchTileState
	tile.kind = tile_state.kind if tile_state != null else 0
	if tile_state != null:
		tile.owner_outline = MatchBoardFactory.owner_color(tile_state.owner, _ctx.rules.territory())
	return tile


## A freshly spawned tile state for [param cell] — a weighted-random kind, tagged with the active side's ownership
## when the board is shared.
func spawn_tile(_board: GridState, cell: Vector2i) -> GridObjectState:
	var cells: Array[Vector2i] = [cell]
	var owner: int = MatchBoardFactory.refill_owner(_ctx.encounter) if _ctx.rules.territory() != null else -1
	return MatchTileState.new(cells, pick_kind(), owner)


## The initial board fill — every cell rolled off the spawn table, with run-avoidance handled by the factory.
func generate_board() -> GridState:
	return MatchBoardFactory.generate_board(_ctx.config, _ctx.rng, _ctx.session, _spawn_table())


## A single weighted-random tile kind off the current spawn table.
func pick_kind() -> int:
	return MatchBoardFactory.pick_kind(_ctx.rng, _spawn_table())


## The tile kind at [param x], [param y] on [param state], or -1 when the cell is empty.
func kind_at(state: GridState, x: int, y: int) -> int:
	return MatchBoardFactory.kind_at(state, x, y)


## The largest match among [param cells] — line clears merge at shared cells; a dragged path counts its length.
## [param allow_diagonal] is the live board knob (passed in, not the snapshot), so a mid-run change is honoured.
func largest_match(board: GridState, cells: Array[Vector2i], is_path: bool, allow_diagonal: bool) -> int:
	var selection: SelectionRule = _ctx.rules.active_selection()
	var min_run: int = selection.min_run if selection != null else 3
	return MatchBoardFactory.largest_match(board, cells, is_path, allow_diagonal, min_run)


# The spawn weights for the active side — its effective ruleset, with warp gated out when warp isn't in play.
func _spawn_table() -> Dictionary:
	var active: Combatant = _ctx.encounter.active_combatant() if _ctx.encounter != null else null
	var source: Ruleset = _ctx.rules.effective_ruleset(active) if active != null and _ctx.ruleset != null else _ctx.ruleset
	return MatchBoardFactory.spawn_table(source, _ctx.readouts.warp_active(), WARP_KIND)
#endregion
