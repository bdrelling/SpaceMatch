class_name MatchClearResolver
extends RefCounted
## Resolves one cleared batch of tiles: measures the batch, fires the ON_CLEAR rules (which bank resources, deal
## damage and charge warp) over the popped cells, then renders the visuals the rules emit. Reads the board, the
## encounter and the sibling collaborators (rules, popups, readouts, wallet) through the shared [MatchContext]. It does
## not own the move's largest-match tally — that flag lives on the coordinator, which folds in each batch's size.

#region Constants

const _WARP_KIND: int = 5
const _DAMAGE_KIND: int = 6

#endregion

#region Properties

var _ctx: MatchContext

#endregion

#region Methods


func _init(ctx: MatchContext) -> void:
	_ctx = ctx


# Fires the ON_CLEAR rules over the popped [param cells] — they bank resources, deal damage and charge warp —
# then renders the emitted visuals. Runs once per cascade step with the cells about to be removed, so the kinds
# are still readable on the board. Returns this batch's largest match (the coordinator folds it into the move's
# running tally for the extra-turn rule).
func resolve_clear(board: GridState, cells: Array[Vector2i], is_path: bool) -> int:
	# Match size is the one shared measure — counting a bent match whole, a path by its length.
	var batch_size: int = _largest_match(board, cells, is_path)
	if _ctx.encounter == null:
		return batch_size
	var active: Combatant = _ctx.encounter.active_combatant()
	# Geometry the ON_CLEAR rules need: per-kind counts, the averaged centre of each kind (for popups), the
	# damage cells (for the fly-to-portrait), and the warp bars this batch earns.
	var counts: Dictionary[int, int] = {}
	var sums: Dictionary[int, Vector2] = {}
	var damage_cells: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var kind: int = MatchBoardFactory.kind_at(board, cell.x, cell.y)
		counts[kind] = counts.get(kind, 0) + 1
		sums[kind] = sums.get(kind, Vector2.ZERO) + _ctx.popups.cell_center(cell)
		if kind == _DAMAGE_KIND:
			damage_cells.append(cell)
	var centers: Dictionary[int, Vector2] = {}
	for kind: int in counts:
		centers[kind] = sums[kind] / float(counts[kind])
	var warp_bars: int = 0
	if counts.has(_WARP_KIND):
		var warp_cells: Array[Vector2i] = []
		for cell: Vector2i in cells:
			if MatchBoardFactory.kind_at(board, cell.x, cell.y) == _WARP_KIND:
				warp_cells.append(cell)
		warp_bars = maxi(0, _largest_match(board, warp_cells, is_path) - 2)
	# Hand it all to the ON_CLEAR rules — they bank resources, deal damage and charge warp, then emit the visual
	# events. The host renders those below (a Resource rule can't spawn scene nodes).
	var match_context := MatchRuleContext.new(board)
	match_context.encounter = _ctx.encounter
	match_context.combatant = active
	match_context.counts = counts
	match_context.centers = centers
	match_context.damage_cells = damage_cells
	match_context.warp_bars = warp_bars
	var scoring_rule := _ctx.rules.rule_of(ScoringRule, _ctx.rules.effective_ruleset(active)) as ScoringRule
	match_context.scoring = scoring_rule.formula if scoring_rule != null else null
	# The mover's scoring offset (set at turn start by an OffsetScoringRule; zero by default) shifts every match's
	# reward down — read here so reward_for honors it without depending on rule-firing order.
	match_context.score_offset = active.score_offset if active != null else 0
	match_context.wallet = wallet()
	match_context.actor_stats = _ctx.rules.effective_stats(active)
	_ctx.rules.run_phase(MatchPhase.ON_CLEAR, match_context)
	render_clear_visuals(match_context)
	return batch_size


# Renders the visual events the ON_CLEAR rules emitted: resource / warp popups, and the damage fly plus its
# delayed hit number. The rules mutate state; the host owns the scene nodes, so visuals come back via the context.
func render_clear_visuals(match_context: MatchRuleContext) -> void:
	var struck: bool = false
	var charged: bool = false
	var banked: bool = false
	for visual: Dictionary in match_context.visuals:
		match visual.get("type", ""):
			"resource":
				banked = true
				var kind: int = visual["kind"]
				var amount: int = visual["amount"]
				var center: Vector2 = visual["center"]
				_ctx.popups.spawn_match_popup(kind, amount, center)
			"warp":
				charged = true
				var bars: int = visual["bars"]
				var warp_center: Vector2 = visual["center"]
				_ctx.popups.spawn_match_popup(_WARP_KIND, bars, warp_center)
			"damage":
				struck = true
				var target: Combatant = visual["target"]
				var damage_cells: Array[Vector2i] = visual["cells"]
				var result: int = visual["result"]
				var dealt: int = visual["dealt"]
				# The damage flies from the match to the struck portrait; the result (or "Dodged!") lands with it.
				_ctx.popups.fly_damage_to_portrait(damage_cells, target)
				_ctx.popups.spawn_portrait_popup_delayed(
					_ctx.popups.portrait_for(target), MatchAbilityBar.damage_text(result, dealt), MatchTile.color_of(_DAMAGE_KIND), _ctx.popups.fly_duration()
				)
	if banked:
		_ctx.readouts.refresh_readouts()
	if struck:
		_ctx.readouts.refresh_health()
	if charged:
		_ctx.readouts.refresh_warp()


# The player's wallet state from the running game, or null when there's no game state.
func wallet() -> WalletState:
	return GameSession.game_state.wallet if GameSession.game_state != null else null


# A match's reward for clearing [param count] tiles of a kind, per the active [ScoringRule]'s formula (one-to-one
# by default; a [FibonacciScoringFormula] makes bigger matches pay super-linearly). Falls back to one-to-one when
# no scoring rule is in play.
func reward_for(count: int) -> int:
	var combatant: Combatant = _ctx.encounter.active_combatant() if _ctx.encounter != null else null
	var scoring_rule := _ctx.rules.rule_of(ScoringRule, _ctx.rules.effective_ruleset(combatant)) as ScoringRule
	return scoring_rule.reward_for(count) if scoring_rule != null else maxi(0, count)


# Adds matched scrap to the player's wallet (a no-op when there's no wallet).
func earn_scrap(amount: int) -> void:
	if GameSession.game_state != null and GameSession.game_state.wallet != null:
		GameSession.game_state.wallet.earn(amount)


# The largest match among [param cells], sized by how it was cleared — the active rule's diagonal / min-run knobs.
func _largest_match(board: GridState, cells: Array[Vector2i], is_path: bool) -> int:
	var selection: SelectionRule = _ctx.rules.active_selection()
	var min_run: int = selection.min_run if selection != null else 3
	return MatchBoardFactory.largest_match(board, cells, is_path, _ctx.allow_diagonal, min_run)

#endregion
