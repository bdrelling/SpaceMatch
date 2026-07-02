class_name MatchGame
extends Control
## The match-3 game: a board of tiles you swap ([[SwapInteraction]]) to line up runs that pop
## ([[MatchClearPassive]]), tiles falling and streaming in ([[GravityPassive]]) so it never stalls. The encounter
## UI (the two portraits) reads the bound game's stats. This node coordinates the collaborators wired in [MatchContext].

#region Signals
## Drives the one-line status string; assigning [member status_text] emits this.
signal status_changed(text: String)
## Asks the host to open a combatant's loadout — emitted when a portrait is tapped, handing the [StarshipState].
signal drill_requested(starship: StarshipState)
## Asks the host to rebuild and reopen the active encounter. The win/lose overlay Restart emits it; standing
## alone, the match restarts itself.
signal restart_requested
#endregion

#region Constants
const _CELL_SIZE: float = 64.0
#endregion

#region Properties
## Forwarded to the blueprint as the board's seed. Zero rolls a fresh board each generation.
@export var board_seed: int = 0
## How the player moves tiles: swap a neighbour, slide a run, or trace a path.
@export var input_mode: MatchBoardView.InputMode = MatchBoardView.InputMode.SWAP
## Count diagonals as adjacent (matches, swaps, connect steps). The one knob.
@export var allow_diagonal: bool = false
## How long the AI opponent "thinks" before playing its swap, so the move reads as a beat. Zero plays immediately.
@export var opponent_move_delay: float = 0.6
## Whether the opponent is computer-controlled. The AI only plays swap; on any other mode it passes. False = human.
@export var ai_opponent: bool = true
## How long an ability's effect plays out before the turn passes. Zero hands over immediately.
@export var action_resolve_delay: float = 0.5
## The mode this match plays — one swappable [Ruleset] of composable [Rule]s. Left unset, falls back to
## [member DebugConfig.match_ruleset] (the standard SpaceMatch set, live-tunable) so it plays standalone.
@export var ruleset: Ruleset
## The board-level config — size, shortest run, warp. Left unset, falls back to [member DebugConfig.match_config].
@export var config: MatchConfig
## Quick Match shows a win/lose overlay with a Restart when a combatant falls. Campaign runs its own end flow.
@export var quick_match: bool = true

var status_text: String = "":
	set(value):
		if value == status_text:
			return
		status_text = value
		status_changed.emit(value)

var _message: String = ""
# The per-combatant state (health, shields, dodge, buffs, matched-tile resources). The match only renders it; a
# host (the [Game] shell or [EncounterScreen]) owns the [Encounter] node and points this at it via bind_session.
var _encounter: EncounterState
# A fallback [Encounter] the match owns ONLY when it stands alone (raw match.tscn, no host), replaced on bind.
var _fallback_encounter: Encounter
# The shared-state object every collaborator reads through (see [MatchContext]), so none holds a back-ref to this
# Node. Built in _ready; its encounter ref is kept current at each rebind / restart.
var _ctx: MatchContext
var _session: GridSession
var _view: GridView
var _grid: Grid
var _match_view: MatchBoardView
var _gravity: MatchGravity
var _rng := RandomNumberGenerator.new()
# Above-the-board overlay floating popups rise into, so they aren't clipped by the board panel.
var _popup_layer: Node2D
# Set once a combatant falls: freezes input and the AI until restart. The win/lose overlay lives on [MatchEndState].
var _game_over: bool = false
# True once the VICTORY/DEFEAT phases have fired for this encounter, so they fire exactly once. Reset on restart.
var _ended: bool = false
# True while an ability use is resolving, before the turn passes — freezes input and the buttons mid-resolve.
var _resolving: bool = false
# Set on the first session bind: the first bind is the initial mount, every later one the shell's Restart.
var _bound: bool = false
# The largest match cleared during the move in progress (accumulated across cascade steps) — the extra-turn lever.
var _move_max_run: int = 0

@onready var _canvas: BoardCanvas = %BoardCanvas
@onready var _player_portrait: PortraitPanel = %PlayerPortrait
@onready var _opponent_portrait: PortraitPanel = %OpponentPortrait
@onready var _round_label: Label = %RoundLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _actions: HBoxContainer = %Actions
#endregion


#region Methods
func _ready() -> void:
	if ruleset == null:
		ruleset = DebugConfig.match_ruleset  # fall back to shared debug rules so the board plays standalone
	if config == null:
		config = DebugConfig.match_config
	_session = MatchBoardFactory.build_session(config, board_seed, input_mode, allow_diagonal, _generate_board)
	_view = MatchGridView.new()
	_view.configure(config.board_width, config.board_height, _CELL_SIZE)
	_grid = _view.grid
	_match_view = MatchBoardView.new()
	_match_view.input_mode = input_mode
	_view.add_child(_match_view)
	_canvas.set_board(_view, _view.content_size())
	_match_view.setup(_session, _grid, _make_tile, _spawn_tile)
	_match_view.move_resolved.connect(_on_move_resolved)
	_canvas.input_handler = _on_board_input  # gated so the human can't move during the AI's turn
	# Bank cleared tiles: hook each clear pass. Cascades go through a MatchClearPassive; TRACE clears inline via
	# the connect interaction, so wire its on_clear to the same banker.
	for clearer: MatchClearPassive in _session.find_rules(MatchClearPassive):
		clearer.on_clear = _on_cells_cleared
	for interaction: GridInteraction in _session.interactions:
		if interaction is ConnectClearInteraction:
			(interaction as ConnectClearInteraction).on_clear = _on_path_cleared
	# Build the context + collaborators before the board generates (generation composes the spawn table + base
	# selection rule through the rules engine). Encounter fills in on fallback open; the popup layer later.
	_ctx = MatchContext.create(self)
	_gravity = MatchGravity.new()
	_gravity.setup(_CELL_SIZE, config.board_width, config.board_height, _session, _spawn_tile)
	_canvas.add_child(_gravity)
	_session.regenerated.connect(_ctx.end_state.on_regenerated)
	_session.regenerate()
	_message = MatchBoardFactory.prompt_for_mode(input_mode, config.min_run)
	_compose_status()
	# Tapping a portrait asks the host to drill into that combatant's module grid (see [signal drill_requested]).
	_player_portrait.pressed.connect(_on_player_pressed)
	_opponent_portrait.pressed.connect(_on_opponent_pressed)
	# Stand alone until a host binds: open a fallback encounter so the board renders (replaced in bind_session).
	if _encounter == null:
		_open_fallback_encounter()
	_watch_encounter()
	_ctx.readouts.configure_warp(quick_match)
	_ctx.readouts.ensure_warp_bar()  # built only when warp is in play; capacity may not be known until a session binds
	_refresh_portraits()
	_refresh_turn_tracker()
	_setup_abilities()
	_popup_layer = Node2D.new()
	add_child(_popup_layer)
	_ctx.popup_layer = _popup_layer
	_ctx.readouts.build_jump_button(_on_jump_pressed)  # the Jump CTA, hidden until the player fills their warp meter
	_refresh_jump()
	_ctx.end_state.build_move_debug()
	_ctx.end_state.refresh_move_debug()
	_ctx.rules.begin_encounter()  # seed SETUP then TURN_START for the first mover


func _sync_context_encounter() -> void:
	if _ctx != null:
		_ctx.encounter = _encounter


func actions() -> Array[MatchAction]:
	var list: Array[MatchAction] = [MatchAction.new("Rules", _open_rules)]
	return list


# Opens the read-only player Rules view — the match defaults plus the player starship's own rules. Done frees it.
func _open_rules() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var navigator := DebugNavigator.create(RulesView.create(ruleset, _ctx.rules.starship_rules(_encounter.player if _encounter != null else null)))
	navigator.closed.connect(layer.queue_free)
	layer.add_child(navigator)
	add_child(layer)


## Mounts the running game (from the [code]GameSession[/code] autoload) so the portraits and top row track the
## host's encounter. Called by the host, which owns the [Encounter] node, so the match drops any standalone fallback.
func bind_session() -> void:
	if _fallback_encounter != null:
		_fallback_encounter.queue_free()
		_fallback_encounter = null
	_encounter = GameSession.game_state.encounter
	_sync_context_encounter()
	_watch_encounter()
	DebugConfig.active_state = GameSession.game_state  # let the Debug stat editor tune this encounter
	_ctx.readouts.configure_warp(quick_match)
	# Now the bound starship is known — drive starting HP from it, then build the warp meter if warp's in play.
	_ctx.readouts.configure_health()
	_ctx.readouts.ensure_warp_bar()
	_refresh_portraits()
	_refresh_turn_tracker()
	# A re-bind is the shell's Restart — the standing board may be frozen on a finished encounter, so start over on
	# a fresh one. The first bind rides on the board _ready already poured; seed its opening turn instead.
	if _bound:
		_restart_board()
	else:
		_ctx.rules.begin_encounter()
	_bound = true


func _refresh_portraits() -> void:
	_ctx.readouts.refresh_portraits(_game_over, _resolving)


func _refresh_dodge() -> void:
	_ctx.readouts.refresh_dodge()


func _player_readouts() -> PackedStringArray:
	return _ctx.readouts.player_readouts()


func _opponent_readouts() -> PackedStringArray:
	return _ctx.readouts.opponent_readouts()


# Drills into a combatant's module grid: hands the shell that combatant's starship (no starship ⇒ no drill).
func _on_player_pressed() -> void:
	var starship: StarshipState = _player_starship()
	if starship != null:
		drill_requested.emit(starship)


func _on_opponent_pressed() -> void:
	var starship: StarshipState = _opponent_starship()
	if starship != null:
		drill_requested.emit(starship)


# Both fight starships are the encounter's. Wraps the rules engine (test-called + used by the drill handlers).
func _player_starship() -> StarshipState:
	return _ctx.rules.player_starship()


func _opponent_starship() -> StarshipState:
	return _ctx.rules.opponent_starship()


# Opens the match's own fallback encounter, ONLY when standalone (no host). GameCoordinator builds the fight and parents the [Starship] nodes under the match.
func _open_fallback_encounter() -> void:
	if _fallback_encounter != null:
		_fallback_encounter.queue_free()
	_fallback_encounter = GameCoordinator.start_quick_match()
	add_child(_fallback_encounter)
	_encounter = _fallback_encounter.state
	_sync_context_encounter()


# Press G to unlock gravity — the tiles fall off the board into a physics heap. One-way for now.
func _unhandled_key_input(event: InputEvent) -> void:
	if _gravity == null or _gravity.is_active():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_G:
		_unlock()
		get_viewport().set_input_as_handled()


# Mount the overlay on the board's current on-screen framing, hand physics the tiles, and kill swap input.
func _unlock() -> void:
	_gravity.position = _view.position
	_gravity.unlock(_grid, _view.scale.x)
	_canvas.input_handler = func(_event: InputEvent) -> bool: return false
	_message = "Gravity unlocked — the tiles broke free."
	_compose_status()


func _compose_status() -> void:
	status_text = _message


func _set_status(text: String) -> void:
	_message = text
	_compose_status()


# A resolved move ends the active combatant's turn and hands the board to the next — unless a MOVE_RESOLVED rule
# (e.g. [ExtraTurnRule]) or a pending Jump keeps the board with the mover. Player and AI both resolve here; a failed swap doesn't burn a turn.
func _on_move_resolved(made_match: bool, cells_cleared: int) -> void:
	if not made_match:
		_move_max_run = 0
		_message = "No match — try another move."
		_compose_status()
		return
	var mover: String = _ctx.readouts.active_name()
	# Read and reset the move's largest match before the next move accumulates into it.
	var max_run: int = _move_max_run
	_move_max_run = 0
	_refresh_portraits()  # fold the cascade's banked totals into the readouts
	if _encounter != null and _encounter.active_combatant() == _encounter.opponent and _encounter.warp_meter.can_jump(false):
		_encounter.warp_meter.jump(false)
	if _check_for_end():
		return
	# The extra-turn rule(s) run on MOVE_RESOLVED, reading the move's largest match and writing go_again + reason.
	var match_context := MatchRuleContext.new(_session.state)
	match_context.encounter = _encounter
	match_context.combatant = _encounter.active_combatant() if _encounter != null else null
	match_context.max_run = max_run
	_ctx.rules.run_phase(MatchPhase.MOVE_RESOLVED, match_context)
	var go_again: bool = match_context.go_again
	var go_again_reason: String = match_context.go_again_reason
	if _encounter != null and _encounter.active_combatant() == _encounter.player and _encounter.warp_meter.can_jump(true):
		go_again = true
	# A resolved move spends one action; the turn passes only once the mover is out. Extra turns and a pending Jump
	# are free. With the default one-action budget this is exactly "a move ends your turn".
	if _encounter != null and not go_again:
		var starship: Combatant = _encounter.active_combatant()
		if starship != null:
			starship.consume_action()
		if starship != null and starship.has_actions_left():
			go_again = true
			if go_again_reason == "":
				go_again_reason = "Action left"
		else:
			_advance_turn()
	if go_again:
		_message = "%s — %s! Take another action." % [mover, go_again_reason]
	elif cells_cleared > 0:
		_message = "%s cleared %d tiles — %s's turn." % [mover, cells_cleared, _ctx.readouts.active_name()]
	else:
		_message = "%s moved — %s's turn." % [mover, _ctx.readouts.active_name()]
	_compose_status()
	_ctx.end_state.refresh_move_debug()
	if not _ctx.end_state.has_moves():
		await _ctx.end_state.reshuffle_board()
	_take_opponent_turn_if_needed()


# The canvas input handler, gated so the human can't move during the AI's turn. Bound to the canvas signal; the gate and the AI live on [MatchTurnLoop].
func _on_board_input(event: InputEvent) -> bool:
	if not _ctx.turn_loop.accepts_player_input(_game_over, _resolving, ai_opponent):
		return false
	return _match_view.handle_event(event)


func _take_opponent_turn_if_needed() -> void:
	await _ctx.turn_loop.take_opponent_turn_if_needed(_game_over, ai_opponent, opponent_move_delay, _gravity, _use_ability, _advance_turn)


func _pass_opponent_turn() -> void:
	_ctx.turn_loop.pass_opponent_turn(_advance_turn)


# Per-clear hooks. Line clears (swap / slide, and every cascade) wire here; the connect interaction (drag/trace)
# wires to _on_path_cleared — the source of the clear picks the sizing rule, not geometry (a 3x2 is a line-clear 3 but a drag 6). The resolver banks.
func _on_cells_cleared(board: GridState, cells: Array[Vector2i]) -> void:
	_move_max_run = maxi(_move_max_run, _ctx.resolver.resolve_clear(board, cells, false))


func _on_path_cleared(board: GridState, cells: Array[Vector2i]) -> void:
	_move_max_run = maxi(_move_max_run, _ctx.resolver.resolve_clear(board, cells, true))


func _reward_for(count: int) -> int:
	return _ctx.resolver.reward_for(count)


func _setup_abilities() -> void:
	_ctx.abilities.setup_abilities(_ctx.rules.starship_abilities(_encounter.player if _encounter != null else null), _on_ability_pressed)
	_refresh_abilities()


func _refresh_abilities() -> void:
	_ctx.abilities.refresh_abilities(_is_player_turn() and not _game_over and not _resolving)


func _on_ability_pressed(ability: Ability) -> void:
	if not _is_player_turn():
		return
	_use_ability(_encounter.player if _encounter != null else null, ability)


# Uses [param ability] for [param combatant]: the engine spends the costs and resolves the effects; the host
# plays out the emitted visuals, then ends the turn (or keeps it) per the mover's policy. Shared by the player and AI. Guarded against a stale call.
func _use_ability(combatant: Combatant, ability: Ability) -> void:
	if _encounter == null or _game_over or _resolving or not MatchAbilityBar.affordable(_encounter, combatant, ability):
		return
	_resolving = true  # freezes input and the buttons until the action finishes resolving
	var context: MatchResolutionContext = await _encounter.use_ability(combatant, ability)
	_ctx.abilities.play_visuals(context)
	_refresh_portraits()
	_message = "%s used %s." % [_ctx.readouts.name_for(combatant), ability.name]
	_compose_status()
	# An attacking ability may have decided the encounter; stop before handing the turn over.
	if _check_for_end():
		_resolving = false
		return
	if action_resolve_delay > 0.0:
		await get_tree().create_timer(action_resolve_delay).timeout
	_resolving = false
	var policy: int = combatant.ability_turn_cost if combatant != null else ActionBudgetRule.AbilityTurnCost.ENDS_TURN
	var ends_turn: bool = true
	if policy == ActionBudgetRule.AbilityTurnCost.FREE:
		ends_turn = false
	elif policy == ActionBudgetRule.AbilityTurnCost.COSTS_ACTION:
		if combatant != null:
			combatant.consume_action()
		ends_turn = combatant == null or not combatant.has_actions_left()
	if ends_turn:
		_advance_turn()
	else:
		_refresh_abilities()
	_take_opponent_turn_if_needed()  # sets the AI playing if the board is now its turn; else no-ops


func _best_affordable_ability(combatant: Combatant) -> Ability:
	return MatchAbilityBar.best_affordable_ability(_encounter, _ctx.rules.starship_abilities(combatant), combatant)


func _is_player_turn() -> bool:
	return _encounter == null or _encounter.active_combatant() == _encounter.player


# Listens for [signal Resource.changed] so a Debug stat edit repaints the readouts at once, and seeds the encounter's effect-engine RNG from the board seed.
func _watch_encounter() -> void:
	if _encounter != null and not _encounter.changed.is_connected(_on_encounter_changed):
		_encounter.changed.connect(_on_encounter_changed)
	if _encounter != null:
		_encounter.runtime().rng_seed = board_seed


func _on_encounter_changed() -> void:
	_ctx.readouts.refresh_health()
	_ctx.readouts.refresh_warp()
	_refresh_jump()


func _exit_tree() -> void:
	if DebugConfig.active_state == GameSession.game_state:
		DebugConfig.active_state = null


func _refresh_jump() -> void:
	_ctx.readouts.refresh_jump(_game_over, _resolving)


# The player taps Jump: expend the full warp meter and win outright. Flow (message, end-check), so it stays here; guarded against a stale tap.
func _on_jump_pressed() -> void:
	if _encounter == null or _game_over or _resolving or not _encounter.warp_meter.can_jump(true):
		return
	_encounter.warp_meter.jump(true)
	_message = "%s jumped to warp — clear of the fight!" % _ctx.readouts.name_for(_encounter.player)
	_compose_status()
	_refresh_portraits()
	_check_for_end()


# Test-called shim onto the board-lifecycle collaborator, which banks the dead board's tiles and repaints the portraits.
func _split_board_resources() -> void:
	_ctx.end_state.split_board_resources()


# Ends the encounter if a combatant has fallen: in Quick Match, shows the win/lose overlay. Returns true when it's over, so callers stop handing the turn.
func _check_for_end() -> bool:
	if _encounter == null or not _encounter.is_over():
		return false
	# Fire the VICTORY / DEFEAT phases once, when the encounter first ends, naming each combatant.
	if not _ended:
		_ended = true
		var loser: Combatant = _encounter.defeated()
		var winner: Combatant = _encounter.opponent_of(loser)
		var win_ctx := _ctx.rules.phase_context()
		win_ctx.combatant = winner
		_ctx.rules.run_phase(MatchPhase.VICTORY, win_ctx)
		var lose_ctx := _ctx.rules.phase_context()
		lose_ctx.combatant = loser
		_ctx.rules.run_phase(MatchPhase.DEFEAT, lose_ctx)
	if quick_match and not _game_over:
		_game_over = true
		_refresh_abilities()
		_ctx.end_state.show_end_overlay(_restart_encounter)
	return true


# Restarts on a fresh encounter (a new [Encounter] node + state). The host reopens one; standalone, the match reopens its own fallback. Wired to Restart.
func _restart_encounter() -> void:
	if _fallback_encounter != null:
		_open_fallback_encounter()
	else:
		restart_requested.emit()
		_encounter = GameSession.game_state.encounter
	_sync_context_encounter()
	_watch_encounter()
	_restart_board()


# Starts the match over on a fresh board against the current encounter: clears the overlay + flags, regenerates, re-runs SETUP. Both Restarts land here.
func _restart_board() -> void:
	_ctx.end_state.hide_end_overlay()
	_game_over = false
	_ended = false
	_resolving = false
	_ctx.readouts.configure_warp(quick_match)
	_move_max_run = 0
	_session.regenerate()  # fresh board, drops in via on_regenerated
	_refresh_portraits()
	_refresh_turn_tracker()
	_ctx.end_state.refresh_move_debug()
	_message = MatchBoardFactory.prompt_for_mode(input_mode, config.min_run)
	_compose_status()
	_ctx.rules.begin_encounter()  # a fresh match is set up — seed SETUP + the first mover's turn-start budget


# Re-syncs the turn's rules, repaints the top row + active portrait (via [MatchReadouts]), and refreshes the dodge
# badges + ability bar. Test-called, stays here.
func _refresh_turn_tracker() -> void:
	# Whose turn it is decides the selection rule and board-level rules (refill, territory) — re-sync before painting.
	_ctx.rules.sync_selection()
	_ctx.rules.sync_board_rules()
	# The engine wrote the applied mode/diagonal onto the context; mirror them back to the exports the rest of the
	# screen (prompt, AI gate, match sizing) and the tests read.
	input_mode = _ctx.input_mode
	allow_diagonal = _ctx.allow_diagonal
	_ctx.readouts.refresh_turn_labels()
	_refresh_dodge()  # a turn change can expire a dodge — keep the badges in step
	_refresh_abilities()  # ability buttons depend on whose turn it is


# Centralised turn handover: fire TURN_END, advance, repaint, tick turn-start decay, fire TURN_START. Phase firing / decay live on the rules engine.
func _advance_turn() -> void:
	if _encounter == null:
		return
	_ctx.rules.run_phase(MatchPhase.TURN_END, _ctx.rules.phase_context())
	_encounter.advance_turn()
	_refresh_turn_tracker()
	_ctx.rules.tick_turn_start_decay()
	_ctx.rules.run_phase(MatchPhase.TURN_START, _ctx.rules.phase_context())


# The session's tile callbacks and the test-facing board queries — thin shims onto [member MatchContext.board].
func _make_tile(object: GridObjectState) -> Node2D:
	return _ctx.board.make_tile(object)


func _spawn_tile(board: GridState, cell: Vector2i) -> GridObjectState:
	return _ctx.board.spawn_tile(board, cell)


func _generate_board() -> GridState:
	return _ctx.board.generate_board()


func _pick_kind() -> int:
	return _ctx.board.pick_kind()


func _kind_at(state: GridState, x: int, y: int) -> int:
	return _ctx.board.kind_at(state, x, y)


func _largest_match(board: GridState, cells: Array[Vector2i], is_path: bool) -> int:
	return _ctx.board.largest_match(board, cells, is_path, allow_diagonal)
#endregion
