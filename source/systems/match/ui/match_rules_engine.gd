class_name MatchRulesEngine
extends RefCounted
## The match's rule seam: composes the effective ruleset (match defaults + the acting starship's rules), fires a
## phase across it, reads config-style rules out of it, and keeps the live board in step with whose turn it is —
## the selection interaction, the fill direction, and territory ownership. Also the source of the acting
## starship's rules / abilities / effective stats. Reads and writes everything through the shared [MatchContext]
## (it is the sole writer of [member MatchContext.input_mode] / [member MatchContext.allow_diagonal]).

#region Properties

var _ctx: MatchContext

# The selection rule synthesized from the legacy mode/diagonal knobs — the base fallback when neither the rules
# nor the active starship names one. Built once so it keeps a stable identity.
var _fallback: SelectionRule
# The selection rule currently applied to the board, so per-turn re-syncs only re-point the view when the active
# rule actually changes (player <-> opponent with different selection overrides).
var _applied_selection: SelectionRule
# The board-fill rule currently applied, so per-turn re-syncs only retune gravity when the active refill
# direction actually changes (e.g. each side filling from its own edge on a shared board).
var _applied_fill: BoardFillRule
# The territory rule in force this turn (tile ownership + team colours), or null when the mode isn't a
# shared-board fight — gates whether refilled tiles are tagged and tinted by side.
var _territory: TerritoryRule

#endregion

#region Methods


func _init(ctx: MatchContext) -> void:
	_ctx = ctx
	# The base selection rule from the legacy knobs — used when neither the rules nor the active starship names one.
	_fallback = SelectionRule.make(SelectionRule.mode_from_input(_ctx.input_mode), _ctx.allow_diagonal, _ctx.config.min_run)


# The territory rule in force this turn, or null on an ordinary board — read by the tile factory for ownership.
func territory() -> TerritoryRule:
	return _territory


# Both fight starships are the encounter's — the player's a clone of the game's persistent starship, the
# opponent's the encounter's own. Null-safe (no encounter => no starship).
func player_starship() -> StarshipState:
	return _ctx.encounter.player.starship if _ctx.encounter != null and _ctx.encounter.player != null else null


func opponent_starship() -> StarshipState:
	return _ctx.encounter.opponent.starship if _ctx.encounter != null and _ctx.encounter.opponent != null else null


func starship_for(combatant: Combatant) -> StarshipState:
	return combatant.starship if combatant != null else null


func loadout_of(starship: StarshipState) -> StarshipLoadout:
	return starship.loadout if starship != null else null


# The acting [param combatant]'s phase rules: its starship's ruleset plus its enabled modules' rules. The match
# layers these over its own defaults each turn (see [method effective_ruleset]), so a starship's extra-turn or
# module behaviour governs its own turn.
func starship_rules(combatant: Combatant) -> Array[Rule]:
	var result: Array[Rule] = []
	if combatant == null:
		return result
	var starship: StarshipState = starship_for(combatant)
	if starship == null:
		return result
	if starship.ruleset != null:
		result.append_array(starship.ruleset.flattened())
	var loadout: StarshipLoadout = loadout_of(starship)
	if loadout != null and _ctx.encounter != null:
		result.append_array(loadout.rules(_ctx.encounter.disabled.cells_of(combatant == _ctx.encounter.player)))
	return result


# The acting [param combatant]'s abilities: its starship's hull kit plus its enabled modules' abilities. Drives
# the player's ability bar and the opponent AI's pick — abilities belong to the starship, never the match.
func starship_abilities(combatant: Combatant) -> Array[Ability]:
	var result: Array[Ability] = []
	if combatant == null:
		return result
	var starship: StarshipState = starship_for(combatant)
	if starship == null:
		return result
	result.append_array(starship.abilities)
	var loadout: StarshipLoadout = loadout_of(starship)
	if loadout != null and _ctx.encounter != null:
		result.append_array(loadout.abilities(_ctx.encounter.disabled.cells_of(combatant == _ctx.encounter.player)))
	return result


# [param combatant]'s effective stats: its starship's own base stat block plus its module-grid profile (honoring
# any disabled cells — the permanent layer), with the encounter's temporary buff layer stacked on top. Empty when
# no encounter or no starship backs the combatant. What the ON_CLEAR rules bonus their grants with, and where
# starship-driven health and warp capacity come from.
func effective_stats(combatant: Combatant) -> StarshipStats:
	if _ctx.encounter == null:
		return StarshipStats.new()
	var starship: StarshipState = starship_for(combatant)
	var base := StarshipStats.new()
	if starship != null and starship.base_stats != null:
		base.add(starship.base_stats)
	var loadout: StarshipLoadout = loadout_of(starship)
	if loadout != null:
		base.add(loadout.stats(_ctx.encounter.disabled.cells_of(combatant == _ctx.encounter.player)))
	return _ctx.encounter.effective_stats(combatant, base)


# Runs every rule registered for [param phase] against [param context] — one phase of play (see [MatchPhase])
# across the effective ruleset: the match's defaults with the acting starship's rules layered over them.
func run_phase(phase: StringName, context: MatchRuleContext) -> void:
	effective_ruleset(context.combatant).run(phase, context)


# The match-scope ruleset with the acting starship's rules layered over it — the same default + per-starship
# override that selection uses. The match ruleset folds in as a nested set and the starship's rules come last, so
# [method Ruleset.resolved] lets a starship rule replace (or stack onto) a match rule of the same combine_key.
# Rebuilt per phase run: cheap, and always current with the acting starship and its enabled modules.
func effective_ruleset(combatant: Combatant) -> Ruleset:
	var composed := Ruleset.new()
	if _ctx.ruleset != null:
		var nested: Array[Ruleset] = [_ctx.ruleset]
		composed.rulesets = nested
	composed.rules = starship_rules(combatant)
	return composed


# The last enabled rule that is [param type] in [param source] (the match ruleset when omitted), or null.
# Config-style rules — scoring, selection default, board fill, territory, reload split — are read out of the
# resolved ruleset this way, so a rule layered in later (a ship's, or one folded in from a nested set) wins.
func rule_of(type: Variant, source: Ruleset = null) -> Rule:
	var search: Ruleset = source if source != null else _ctx.ruleset
	if search == null:
		return null
	var found: Rule = null
	for rule: Rule in search.resolved():
		if rule != null and rule.enabled and is_instance_of(rule, type):
			found = rule
	return found


# A minimal context for a lifecycle phase (no per-clear payload): the encounter and the active combatant.
func phase_context() -> MatchRuleContext:
	var match_context := MatchRuleContext.new(_ctx.session.state if _ctx.session != null else null)
	match_context.encounter = _ctx.encounter
	match_context.combatant = _ctx.encounter.active_combatant() if _ctx.encounter != null else null
	return match_context


# Seeds a fresh match's opening turn: fires SETUP, then TURN_START for the first mover — so the turn-start rules
# (action budget, resource capacity, scoring offset) configure them before they act, exactly as every later turn
# boundary does via the coordinator's advance-turn.
func begin_encounter() -> void:
	run_phase(MatchPhase.SETUP, phase_context())
	tick_turn_start_decay()
	run_phase(MatchPhase.TURN_START, phase_context())


# Fires the engine's turn-start phase decay for the active combatant: its statuses' TimingDecayRules tick (and
# expire) through DecayEngine. A bare-phase tick completes synchronously (our statuses carry no phase-triggered
# effects). The dodge's own per-turn expiry stays in EncounterState.advance_turn (its single decay slot holds the
# on-hit rule), so this is the seam for shield/turn-scoped statuses without disturbing dodge.
func tick_turn_start_decay() -> void:
	if _ctx.encounter == null:
		return
	var mover: Combatant = _ctx.encounter.active_combatant()
	if mover == null:
		return
	var allies: Array[Entity] = []
	allies.append(mover)
	var foes: Array[Entity] = []
	var foe: Combatant = _ctx.encounter.opponent_of(mover)
	if foe != null:
		foes.append(foe)
	_ctx.encounter.runtime().tick_phase(mover, allies, foes, &"turn_start")


# The starship acting this turn (the player's, or the opponent's on its turn). Null-safe for the standalone scene.
func active_starship() -> StarshipState:
	if _ctx.encounter != null and _ctx.encounter.active_combatant() == _ctx.encounter.opponent:
		return opponent_starship()
	return player_starship()


# The selection rule in force this turn: the active starship's override wins, else the encounter's default, else
# the legacy-knob fallback. Never null once the engine has been built.
func active_selection() -> SelectionRule:
	var starship: StarshipState = active_starship()
	if starship != null and starship.selection_override != null:
		return starship.selection_override
	var default_rule := rule_of(SelectionDefaultRule) as SelectionDefaultRule
	if default_rule != null and default_rule.selection != null:
		return default_rule.selection
	return _fallback


# Re-points the board at the active turn's selection rule, but only when it actually changed — so a board whose
# combatants share one rule never churns the view, while differing per-starship rules switch on the turn.
func sync_selection() -> void:
	if _ctx.session == null or _ctx.match_view == null:
		return
	var selection: SelectionRule = active_selection()
	if selection == null or selection == _applied_selection:
		return
	apply_selection(selection)
	_applied_selection = selection


# Applies a selection rule live: enables exactly its interaction, retunes adjacency / run length / range on every
# verb and match condition, and re-points the view's input handling. No board rebuild — the verbs all live in the
# session already (see [MatchBlueprint]); this just flips which one is live.
func apply_selection(rule: SelectionRule) -> void:
	if rule == null or _ctx.session == null:
		return
	var mode: MatchBoardView.InputMode = rule.input_mode()
	for interaction: GridInteraction in _ctx.session.interactions:
		if interaction is SwapInteraction:
			interaction.enabled = mode == MatchBoardView.InputMode.SWAP
			(interaction as SwapInteraction).allow_diagonal = rule.allow_diagonal
			(interaction as SwapInteraction).revert_without_match = rule.match_required
		elif interaction is LineShiftInteraction:
			interaction.enabled = mode == MatchBoardView.InputMode.LINE_SHIFT
			(interaction as LineShiftInteraction).revert_without_match = rule.match_required
		elif interaction is TeleportInteraction:
			interaction.enabled = mode == MatchBoardView.InputMode.TELEPORT
			(interaction as TeleportInteraction).revert_without_match = rule.match_required
			(interaction as TeleportInteraction).max_range = rule.teleport_range
		elif interaction is ConnectClearInteraction:
			interaction.enabled = mode == MatchBoardView.InputMode.CONNECT
			(interaction as ConnectClearInteraction).allow_diagonal = rule.allow_diagonal
			(interaction as ConnectClearInteraction).min_run_length = rule.min_run
	for condition: MatchLineCondition in _ctx.session.find_rules(MatchLineCondition):
		condition.diagonal = rule.allow_diagonal
		condition.min_run_length = rule.min_run
	if _ctx.match_view != null:
		_ctx.match_view.refresh_mode(mode)
	# Mirror onto the context the rest of the screen reads (the prompt, the AI gate, the debug chip).
	_ctx.input_mode = mode
	_ctx.allow_diagonal = rule.allow_diagonal


# Re-derives the board-level rules that depend on whose turn it is — refill direction and territory ownership —
# from the effective ruleset (the same compose that drives every phase), applying fill only when it changed so a
# board whose combatants share one direction never churns gravity. Sourcing from the ruleset is what makes these
# compose: a mode authors them into its ruleset, a ship overrides by rule_name on its turn.
func sync_board_rules() -> void:
	if _ctx.session == null:
		return
	var combatant: Combatant = _ctx.encounter.active_combatant() if _ctx.encounter != null else null
	var effective: Ruleset = effective_ruleset(combatant)
	# Both are the last enabled rule of their kind in the composed ruleset, so a ship/module rule layered over the
	# match default wins on that ship's turn.
	var fill := rule_of(BoardFillRule, effective) as BoardFillRule
	if fill != _applied_fill:
		apply_fill(fill)
		_applied_fill = fill
	# Territory's presence is what turns on tile ownership and tinting; null leaves an ordinary board.
	_territory = rule_of(TerritoryRule, effective) as TerritoryRule


# Sets the gravity direction live on every gravity rule in the session — the one knob that decides which way
# tiles settle and which edge fresh tiles stream in. Null fill = the default downward fall.
func apply_fill(fill: BoardFillRule) -> void:
	var dir: Vector2i = fill.direction_vector() if fill != null else Vector2i(0, 1)
	for gravity: GravityPassive in _ctx.session.find_rules(GravityPassive):
		gravity.direction = dir

#endregion
