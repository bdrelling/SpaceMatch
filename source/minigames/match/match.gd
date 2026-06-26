class_name MatchMinigame
extends Minigame
## Match-3 minigame. A board of tiles: grab a tile and drag it toward a neighbour to swap
## ([[SwapInteraction]]), line up three-or-more of one kind and they pop ([[MatchClearPassive]]). Tiles
## fall and fresh ones stream in ([[GravityPassive]]); the board is an equal-frequency generator, so it
## never stalls. The board owns its tiles and rules; the encounter HUD around it (the two portraits)
## reads the bound game's starship stats and [Wallet] once a session is bound.

const _CELL_SIZE: float = 64.0
const _KIND_COUNT: int = MatchTile.KIND_COUNT

# The four colored stat tiles (combat, propulsion, science, defense) whose match counts show as
# resources beneath the portraits, in [MatchTile] kind order — index-aligned with PortraitPanel's strip.
# The other three kinds route elsewhere: scrap (kind 4) banks into the wallet, damage (kind 6) depletes
# the opposing combatant's health, and warp (kind 5) charges the encounter's warp meter.
const _STAT_KINDS: Array[int] = [0, 1, 2, 3]
const _SCRAP_KIND: int = 4
const _WARP_KIND: int = 5
const _DAMAGE_KIND: int = 6

# Damage tiles fly from the match to the target portrait before the hit lands: glyph size, travel time,
# the impact pop at the end, and the head-start between successive tiles so they stream rather than stack.
const _FLY_TILE_PX: float = 54.0
const _FLY_DURATION: float = 0.5
const _FLY_POP: float = 0.13
const _FLY_STAGGER: float = 0.07

## Forwarded to the blueprint as the board's seed. Zero rolls a fresh board each generation.
@export var board_seed: int = 0

## How the player moves tiles: swap a neighbour, slide a run, or trace a path.
@export var input_mode: MatchBoardView.InputMode = MatchBoardView.InputMode.SWAP
## Count diagonals as adjacent (matches, swaps, connect steps). The one knob.
@export var allow_diagonal: bool = false
## How long the AI opponent "thinks" before playing its swap, so the move reads as
## a deliberate beat rather than an instant jump. Zero plays immediately.
@export var opponent_move_delay: float = 0.6
## Whether the opponent is computer-controlled. The AI can only play swap for now; on any other selection
## mode it reports the gap and passes. Set false for a human opponent sharing the board (and in tests).
@export var ai_opponent: bool = true
## How long an ability's effect and animation play out before the turn passes, so the action finishes
## resolving before the next combatant acts. Zero hands over immediately.
@export var action_resolve_delay: float = 0.5
## The swappable rules for this encounter — spawn weights and the extra-turn threshold. Left unset, the
## board falls back to [member DebugConfig.match_rules] (the standard SpaceMatch set, live-tunable from the
## Debug panel) so it plays standalone.
@export var rules: MatchRules
## The board-level config — size, shortest run, and whether warp is in play. Left unset, the board falls
## back to [member DebugConfig.match_config] (shared, live-tunable from the Debug panel) so it plays standalone.
@export var config: MatchConfig
## Quick Match shows a win/lose overlay with a Restart when a combatant falls, replaying the same board.
## Campaign sets this false and runs the encounter end through its own flow.
@export var quick_match: bool = true

@onready var _canvas: BoardCanvas = %BoardCanvas
@onready var _player_portrait: PortraitPanel = %PlayerPortrait
@onready var _opponent_portrait: PortraitPanel = %OpponentPortrait
@onready var _round_label: Label = %RoundLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _actions: HBoxContainer = %Actions

var _message: String = ""
# The encounter holds the per-combatant state — health, shields, dodge, the temporary stat-buff layer, and
# the matched-tile resources the readouts show and abilities spend. The match only renders it; a host (the
# [Game] shell or [EncounterScreen]) owns the [Encounter] node and points this at it via [method bind_session].
var _encounter: EncounterState
# A fallback [Encounter] the match owns ONLY when it stands alone (raw match.tscn, no host) — built in
# [method _ready] so the board renders, and replaced by the host's encounter on bind. Null when hosted.
var _fallback_encounter: Encounter

var _session: GridSession
var _view: GridView
var _grid: Grid
var _match_view: MatchBoardView
var _gravity: MatchGravity
var _rng := RandomNumberGenerator.new()

# Above-the-board overlay that floating match/damage popups are spawned into, so they rise unclipped over
# the HUD. The ability buttons under the board, left to right, index-aligned with [member _player_abilities].
var _popup_layer: Node2D
var _ability_buttons: Array[Button] = []
# The player ship's abilities, captured when the bar is wired (see [method _setup_abilities]) — what the
# buttons map to. Abilities are the ship's, not the match's.
var _player_abilities: Array[MatchAbility] = []
# The "JUMP" call-to-action, shown only when the player has filled their warp meter (see [method _refresh_jump]).
var _jump_button: Button
# The shared warp meter's segment cells, left to right, sitting immediately above the board. Filled to show
# the meter's magnitude in the leader's color (see [method _refresh_warp]).
var _warp_segments: Array[Panel] = []
# Warp segment fills: the player pulls the meter one way (purple, the Warp tile color), the opponent the
# other (red — the Quick Match tug). The meter is signed, so only the leader's color shows at a time.
const _WARP_PLAYER_FILL := Color(0.66, 0.47, 0.86)
const _WARP_OPPONENT_FILL := Color(0.88, 0.40, 0.42)
# A flat-colored debug chip over the board showing the live available-move count; remove with its build call.
var _move_debug_label: Label
# True while a reshuffle is dropping/rebuilding the board, so the regenerate it triggers doesn't re-check
# for a dead board and recurse.
var _reshuffling: bool = false
# Set once a combatant falls: freezes input and the AI until the encounter restarts. The win/lose overlay
# (Quick Match only), parented to this screen, is held here so the restart can tear it down.
var _game_over: bool = false
# True once the VICTORY/DEFEAT phases have fired for this encounter, so they fire exactly once. Reset on restart.
var _ended: bool = false
var _end_overlay: Control
# True while an action (an ability use) is playing out, before the turn passes — freezes input and the
# ability buttons so nothing else fires mid-resolve.
var _resolving: bool = false
# Set on the first session bind. The first bind is the initial mount, where _ready already poured the board;
# every later bind is the shell's Restart (Settings menu), which has to start the match over on a fresh board.
var _bound: bool = false

# Every tile kind, cached as the default spawn pool so refills don't rebuild the list each cascade step.
var _all_kinds: Array[int] = []
# The largest match cleared during the move in progress, accumulated across its cascade steps in
# [method _on_cells_cleared] and read by [method _on_move_resolved] for the extra-turn rule.
var _move_max_run: int = 0

# The selection rule synthesized from the legacy mode/diagonal exports — the base fallback when neither the
# rules nor the active ship names one. Built once in _ready so it keeps a stable identity.
var _fallback: SelectionRule
# The selection rule currently applied to the board, so per-turn re-syncs only re-point the view when the
# active rule actually changes (player ↔ opponent with different selection overrides).
var _applied_selection: SelectionRule

func _ready() -> void:
	# Fall back to the shared debug rules so the board plays when mounted without authored rules of its own,
	# and so the Debug panel's live edits reach the running board (it shares this instance).
	if rules == null:
		rules = DebugConfig.match_rules
	# Same fallback for the board-level config, so size / min-run / warp tune live from the Debug panel.
	if config == null:
		config = DebugConfig.match_config
	for kind: int in _KIND_COUNT:
		_all_kinds.append(kind)

	var blueprint := MatchBlueprint.new()
	blueprint.rng_seed = board_seed
	blueprint.input_mode = input_mode
	blueprint.allow_diagonal = allow_diagonal
	blueprint.board_width = config.board_width
	blueprint.board_height = config.board_height
	blueprint.min_run = config.min_run
	blueprint.build()
	_session = GridSession.create(blueprint)
	_session.generator = CallableGridGenerator.create(_generate_board)

	_view = MatchGridView.new()
	_view.configure(config.board_width, config.board_height, _CELL_SIZE)
	_grid = _view.grid
	_match_view = MatchBoardView.new()
	_match_view.input_mode = input_mode
	_view.add_child(_match_view)
	_canvas.set_board(_view, _view.content_size())
	_match_view.setup(_session, _grid, _make_tile, _spawn_tile)
	_match_view.move_resolved.connect(_on_move_resolved)
	# The canvas feeds pointer events to the view from its _gui_input, gated so the
	# human can't move during the AI opponent's turn.
	_canvas.input_handler = _on_board_input

	# Bank cleared tiles by kind: hook each clear pass so every popped tile banks into the active combatant's
	# encounter resources. SWAP / SLIDE / TELEPORT cascade through a MatchClearPassive; TRACE clears inline
	# via the connect interaction, so wire its on_clear to the same banker.
	for clearer: MatchClearPassive in _session.find_rules(MatchClearPassive):
		clearer.on_clear = _on_cells_cleared
	for interaction: GridInteraction in _session.interactions:
		if interaction is ConnectClearInteraction:
			(interaction as ConnectClearInteraction).on_clear = _on_path_cleared

	# The base selection rule from the legacy exports — used when neither the rules nor the active ship names
	# one. Built before the first turn-tracker refresh, which applies the active rule to the board.
	_fallback = SelectionRule.make(SelectionRule.mode_from_input(input_mode), allow_diagonal, config.min_run)

	# The "unlock" mechanic: an idle physics overlay mounted alongside the board, woken by a keypress.
	_gravity = MatchGravity.new()
	_gravity.setup(_CELL_SIZE, config.board_width, config.board_height, _session, _spawn_tile)
	_canvas.add_child(_gravity)

	_session.regenerated.connect(_on_regenerated)
	_session.regenerate()
	_message = _prompt_for_mode()
	_compose_status()

	# Tapping a portrait drills into that combatant's module grid. The board names no screen — it just
	# asks the shell to drill and hands it whose ship to show (see [signal Minigame.drill_requested]).
	_player_portrait.pressed.connect(_on_player_pressed)
	_opponent_portrait.pressed.connect(_on_opponent_pressed)

	# Stand alone until a host binds: open a fallback encounter (raw match.tscn run directly) so the board
	# renders. A host replaces it in [method bind_session] with the encounter it owns.
	if _encounter == null:
		_open_fallback_encounter()
	_watch_encounter()
	_configure_warp()
	# The meter is built only when warp is actually in play (rule on, a ship can warp); _spawn_table keeps
	# warp tiles off the board otherwise. Capacity may not be known until a session binds, so this also runs
	# from bind_session.
	_ensure_warp_bar()
	_refresh_portraits()
	_refresh_turn_tracker()

	# The buttons under the board are the encounter's abilities — wired from the rules.
	_setup_abilities()

	# Floating match/damage popups rise into an overlay above the board so they aren't clipped by the
	# board panel. Added last so it draws over the whole screen.
	_popup_layer = Node2D.new()
	add_child(_popup_layer)

	# The Jump call-to-action — hidden until the player fills their warp meter.
	_build_jump_button()
	_refresh_jump()

	_build_move_debug()
	_refresh_move_debug()

	# The match is set up — let SETUP rules seed starting state before the first turn.
	_run_phase(MatchPhase.SETUP, _phase_context())

func actions() -> Array[MinigameAction]:
	# The player-facing Rules button lives in the top bar — a read-only summary of this match's rules.
	var list: Array[MinigameAction] = [MinigameAction.new("Rules", _open_rules)]
	return list

# Opens the read-only player Rules view over the board (a top-most layer; the dim blocks the board behind).
# Reads this match's own rules, so it reflects exactly the rules in force. Done frees it.
func _open_rules() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	# Show the match's defaults plus the player ship's own rules (extra turn, module rules) — the set actually
	# in force on the player's turn, not just the match scope.
	var navigator := DebugNavigator.create(RulesView.create(rules, _ship_rules(EncounterState.Combatant.PLAYER)))
	navigator.closed.connect(layer.queue_free)
	layer.add_child(navigator)
	add_child(layer)

#region Portraits

## Mounts the running game (read from the [code]GameSession[/code] autoload) so the portraits show each ship's
## stats and the player's wallet, and the top row tracks the encounter's turns. Called by the host when it
## mounts this page; the host owns the [Encounter] node, so the match drops any standalone fallback and renders
## the host's encounter.
func bind_session() -> void:
	if _fallback_encounter != null:
		_fallback_encounter.queue_free()
		_fallback_encounter = null
	_encounter = GameSession.game_state.encounter
	_watch_encounter()
	# Hand the live state to the Debug panel so the stat editor can tune this encounter's health and stats.
	DebugConfig.active_state = GameSession.game_state
	_configure_warp()
	# Now the bound ship is known — drive starting HP from it, then build the warp meter if warp's in play.
	_configure_health()
	_ensure_warp_bar()
	_refresh_portraits()
	_refresh_turn_tracker()
	# A re-bind is the shell's Restart (the Settings menu rebuilds the session and rebinds every screen). The
	# board from the first mount is still standing — and may be frozen on a finished encounter — so start the
	# match over on a fresh one. The very first bind rides on the board _ready already poured.
	if _bound:
		_restart_board()
	_bound = true

func _refresh_portraits() -> void:
	if _player_portrait != null:
		_player_portrait.set_readouts(_player_readouts())
		_player_portrait.set_module_grid(_grid_of(_player_starship()))
	if _opponent_portrait != null:
		_opponent_portrait.set_readouts(_opponent_readouts())
		_opponent_portrait.set_module_grid(_grid_of(_opponent_starship()))
	_refresh_health()
	_refresh_warp()
	_refresh_abilities()
	_refresh_jump()

# Repaints both portraits' health bars from the encounter's current health.
func _refresh_health() -> void:
	if _encounter == null:
		return
	if _player_portrait != null:
		_player_portrait.set_health(_encounter.player_health, _encounter.player_max_health, _encounter.player_shield)
	if _opponent_portrait != null:
		_opponent_portrait.set_health(_encounter.opponent_health, _encounter.opponent_max_health, _encounter.opponent_shield)
	_refresh_dodge()

# Toggles each portrait's EVADE badge to match the encounter's dodge state — armed by Evasive Maneuvers, spent
# by the next attack, expired when the owner's turn returns — so a live dodge is always visible on the HUD.
func _refresh_dodge() -> void:
	if _encounter == null:
		return
	if _player_portrait != null:
		_player_portrait.set_dodge_active(_encounter.dodge_of(EncounterState.Combatant.PLAYER))
	if _opponent_portrait != null:
		_opponent_portrait.set_dodge_active(_encounter.dodge_of(EncounterState.Combatant.OPPONENT))

# Repaints the warp bar above the board as a tug of war: the side currently ahead sets the bar's length to its
# own capacity and fills toward its own Jump — the player from the left (purple), the opponent from the right
# (red). So a player two bars into a four-bar core shows four cells filling from the left; flip the lead to a
# six-bar opponent two bars in and it shows six cells, two filled from the right. Segments past the leader's
# capacity are hidden, so the bar's width tracks whoever is winning.
func _refresh_warp() -> void:
	if _encounter == null or _warp_segments.is_empty():
		return
	var leads_player: bool = _encounter.warp >= 0
	var capacity: int = _encounter.player_warp_max if leads_player else _encounter.opponent_warp_max
	var level: int = absi(_encounter.warp)
	var fill: Color = _WARP_PLAYER_FILL if leads_player else _WARP_OPPONENT_FILL
	for i: int in _warp_segments.size():
		var visible: bool = i < capacity
		_warp_segments[i].visible = visible
		if not visible:
			continue
		# Player fills left-to-right (the first `level` cells); the opponent fills right-to-left (the last
		# `level` cells of its capacity), so each side charges from its own edge of the meter.
		var filled: bool = (i < level) if leads_player else (i >= capacity - level)
		_paint_warp_segment(_warp_segments[i], filled, fill)

# The four resource readouts beneath the player portrait, in [constant _STAT_KINDS] order (combat,
# propulsion, science, defense): the tiles the player has matched of each kind this encounter. Starts at
# zero — these are matched-this-fight resources, not the ship's base stats (those live on the stats screen).
func _player_readouts() -> PackedStringArray:
	return _readouts_for(EncounterState.Combatant.PLAYER)

# The opponent's four resource readouts — its own matched-this-encounter resources.
func _opponent_readouts() -> PackedStringArray:
	return _readouts_for(EncounterState.Combatant.OPPONENT)

# A combatant's four stat-tile readouts: the count matched of each kind this fight, read off the encounter.
func _readouts_for(combatant: int) -> PackedStringArray:
	var out := PackedStringArray()
	for kind: int in _STAT_KINDS:
		out.append(str(_resource_of(combatant, kind)))
	return out

# A combatant's banked count of a kind this encounter (zero when there's no encounter yet).
func _resource_of(combatant: int, kind: int) -> int:
	return _encounter.resource_of(combatant, kind) if _encounter != null else 0

# Drills into a combatant's module grid: hands the shell that combatant's ship so the Loadout stage
# opens it. No ship (e.g. running this scene standalone, no bound session) ⇒ no drill.
func _on_player_pressed() -> void:
	var starship: StarshipState = _player_starship()
	if starship != null:
		drill_requested.emit(starship)

func _on_opponent_pressed() -> void:
	var starship: StarshipState = _opponent_starship()
	if starship != null:
		drill_requested.emit(starship)

# Both fight ships are the encounter's now — the player's a clone of the game's persistent starship (see
# [method _seed_player_ship]), the opponent's the encounter's own. Null-safe (no encounter ⇒ no ship).
func _player_starship() -> StarshipState:
	return _encounter.player if _encounter != null else null

func _opponent_starship() -> StarshipState:
	return _encounter.opponent if _encounter != null else null

# Opens the match's own fallback encounter, used ONLY when it stands alone (raw match.tscn, no host). The
# player combatant clones the running ship (so a fresh fight starts from a fresh copy), the opponent is the
# computer default; the [Encounter] node parents the two combatant [Starship] nodes under the match so the
# fight lives in the hierarchy, and its state is pointed into the session. Frees any prior fallback first.
func _open_fallback_encounter() -> void:
	if _fallback_encounter != null:
		_fallback_encounter.queue_free()
	var player_clone: StarshipState = null
	if GameSession.game_state != null and GameSession.game_state.starship != null:
		player_clone = GameSession.game_state.starship.clone()
	_fallback_encounter = Encounter.create(player_clone)
	add_child(_fallback_encounter)
	_encounter = _fallback_encounter.state
	if GameSession.game_state != null:
		GameSession.game_state.encounter = _encounter

func _starship_for(combatant: int) -> StarshipState:
	return _player_starship() if combatant == EncounterState.Combatant.PLAYER else _opponent_starship()

func _grid_of(starship: StarshipState) -> ModuleGridState:
	return starship.module_grid if starship != null else null

# The acting [param combatant]'s phase rules: its ship's ruleset plus its enabled modules' rules. The match
# layers these over its own defaults each turn (see [method _effective_ruleset]), so a ship's extra-turn or
# module behaviour governs its own turn.
func _ship_rules(combatant: int) -> Array[Rule]:
	var result: Array[Rule] = []
	if combatant < 0:
		return result
	var ship: StarshipState = _starship_for(combatant)
	if ship == null:
		return result
	if ship.ruleset != null:
		result.append_array(ship.ruleset.rules)
	var grid: ModuleGridState = _grid_of(ship)
	if grid != null and _encounter != null:
		result.append_array(grid.rules(_encounter.disabled_cells_of(combatant)))
	return result

# The acting [param combatant]'s abilities: its ship's hull kit plus its enabled modules' abilities. Drives
# the player's ability bar and the opponent AI's pick — abilities belong to the ship, never the match.
func _ship_abilities(combatant: int) -> Array[MatchAbility]:
	var result: Array[MatchAbility] = []
	if combatant < 0:
		return result
	var ship: StarshipState = _starship_for(combatant)
	if ship == null:
		return result
	result.append_array(ship.abilities)
	var grid: ModuleGridState = _grid_of(ship)
	if grid != null and _encounter != null:
		result.append_array(grid.abilities(_encounter.disabled_cells_of(combatant)))
	return result

# [param combatant]'s effective stats: its ship's own base stat block plus its module-grid profile (honoring
# any disabled cells — the permanent layer), with the encounter's temporary buff layer stacked on top. Empty
# when no encounter or no ship backs the combatant (the standalone scene). What the ON_CLEAR rules bonus their
# grants with, and where ship-driven health and warp capacity come from.
func _effective_stats(combatant: int) -> StatBlock:
	if _encounter == null:
		return StatBlock.new()
	var ship: StarshipState = _starship_for(combatant)
	var base := StatBlock.new()
	if ship != null and ship.stats != null:
		base.add(ship.stats)
	var grid: ModuleGridState = _grid_of(ship)
	if grid != null:
		base.add(grid.profile(_encounter.disabled_cells_of(combatant)))
	return _encounter.effective_stats(combatant, base)

#endregion

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

#region Match-3

func _compose_status() -> void:
	status_text = _message

# A resolved move ends the active combatant's turn and hands the board to the next — unless a MOVE_RESOLVED
# rule (e.g. [ExtraTurnRule]) keeps the board with the mover for another go. The player and the AI opponent both resolve through here — the
# opponent's swap re-enters this on completion, handing the turn back (or taking another), so the volley
# stops once it's the player's turn again. A failed swap doesn't burn a turn. Tallied matches bank into
# the portrait readouts and update between turns.
func _on_move_resolved(made_match: bool, cells_cleared: int) -> void:
	if not made_match:
		_move_max_run = 0
		_message = "No match — try another move."
		_compose_status()
		return
	var mover: String = _active_name()
	# Read and reset the move's largest match before the next move accumulates into it.
	var max_run: int = _move_max_run
	_move_max_run = 0
	# The tally grew during the cascade (via _on_cells_cleared) — fold the new totals into the readouts.
	_refresh_portraits()
	# A move that maxed warp can be cashed in for a Jump. The AI opponent does so immediately (Quick Match);
	# the player chooses via the Jump button, and keeps the turn below so they can.
	if _encounter != null and _encounter.active_combatant() == EncounterState.Combatant.OPPONENT and _encounter.can_jump(EncounterState.Combatant.OPPONENT):
		_encounter.jump(EncounterState.Combatant.OPPONENT)
	# Damage (or a warp Jump) during the move may have decided the encounter — stop here and show the result.
	if _check_for_end():
		return
	# The extra-turn rule(s) run on MOVE_RESOLVED and decide whether the mover keeps the board. The context
	# carries the move's largest match in, and the rules write go_again (and a reason) back.
	var ctx := MatchRuleContext.new(_session.state)
	ctx.encounter = _encounter
	ctx.combatant = _encounter.active_combatant() if _encounter != null else -1
	ctx.max_run = max_run
	_run_phase(MatchPhase.MOVE_RESOLVED, ctx)
	var go_again: bool = ctx.go_again
	# Maxing warp keeps the board with the player so they can choose to Jump before the turn passes.
	if _encounter != null and _encounter.active_combatant() == EncounterState.Combatant.PLAYER and _encounter.can_jump(EncounterState.Combatant.PLAYER):
		go_again = true
	if _encounter != null and not go_again:
		_advance_turn()
	if go_again:
		_message = "%s — %s! Take another action." % [mover, ctx.go_again_reason]
	elif cells_cleared > 0:
		_message = "%s cleared %d tiles — %s's turn." % [mover, cells_cleared, _active_name()]
	else:
		_message = "%s moved — %s's turn." % [mover, _active_name()]
	_compose_status()
	_refresh_move_debug()
	# A dead board (no swap makes a match) reshuffles before anyone acts on it.
	if not _has_moves():
		await _reshuffle_board()
	_take_opponent_turn_if_needed()

#region AI opponent

# Routes pointer events to the board, but only when the human may act — the AI
# opponent's turn (its think beat and its move) is hands-off so the player can't
# move on its behalf.
func _on_board_input(event: InputEvent) -> bool:
	if not _accepts_player_input():
		return false
	return _match_view.handle_event(event)

func _accepts_player_input() -> bool:
	if _game_over or _resolving:
		return false
	if _encounter == null or not _ai_controls_opponent():
		return true
	return _encounter.active_combatant() == EncounterState.Combatant.PLAYER

# Whether the opponent is computer-controlled. When false, the opponent shares the board as a human and
# the AI never acts (used for a hot-seat opponent and to isolate turn logic in tests).
func _ai_controls_opponent() -> bool:
	return ai_opponent

# When the turn has passed to the AI opponent, think for a beat, then play the best
# move the solver can find. Fire-and-forget: the resulting move re-enters
# [method _on_move_resolved], which hands the turn back to the player.
func _take_opponent_turn_if_needed() -> void:
	if _game_over or not _ai_controls_opponent() or _match_view == null:
		return
	if _encounter == null or _encounter.active_combatant() != EncounterState.Combatant.OPPONENT:
		return
	if opponent_move_delay > 0.0:
		await get_tree().create_timer(opponent_move_delay).timeout
	# The board may have torn down (e.g. screen left) during the think beat — bail before touching it.
	if not is_inside_tree() or _encounter == null:
		return
	# State can shift during the think beat (e.g. gravity unlocked) — re-check before moving.
	if _encounter.active_combatant() != EncounterState.Combatant.OPPONENT:
		return
	if _gravity != null and _gravity.is_active():
		return
	# Spend gems on an attack when it can afford one — an ability ends the turn, so it's played instead of a
	# board move (and works in any selection mode, since it's not a board move).
	var ability: MatchAbility = _best_affordable_ability(EncounterState.Combatant.OPPONENT)
	if ability != null:
		_use_ability(EncounterState.Combatant.OPPONENT, ability)
		return
	# The AI can only solve swaps for now. On any other selection mode (the opponent's ship forced slide /
	# trace / teleport), report the gap loudly and pass rather than soft-lock — build the matching solver
	# (mirror SwapSolver for that interaction) when an opponent needs to play it.
	if input_mode != MatchBoardView.InputMode.SWAP:
		var mode_name: String = MatchBoardView.InputMode.keys()[input_mode]
		push_error("MatchMinigame: AI opponent has no solver for %s yet — not implemented." % mode_name)
		_message = "Opponent can't play %s yet — passing." % mode_name.to_lower()
		_compose_status()
		_pass_opponent_turn()
		return
	var swap := _session.find_interaction(GridInteraction.Gesture.SWIPE) as SwapInteraction
	var move: Array[Vector2i] = SwapSolver.best_move(_session.state, swap)
	if move.is_empty():
		_pass_opponent_turn()
		return
	await _match_view.perform_move(move)

# A dead board (no swap makes a match) — skip the opponent's move so play doesn't
# stall, handing the turn straight back to the player.
func _pass_opponent_turn() -> void:
	var passer: String = _active_name()
	if _encounter != null:
		_advance_turn()
	_message = "%s has no move — %s's turn." % [passer, _active_name()]
	_compose_status()

#endregion

# Per-clear hooks. A line clear (swap / slide / teleport, and every cascade) sizes its match by intersecting
# straight runs; a drag/trace clear sizes it by the traced path. The two can't be told apart from the cells
# alone — a 3x2 is two 3-runs to a line clear but a single 6-path to a drag — so the source of the clear
# picks the rule, never the geometry. The connect interaction wires to _on_path_cleared, everything else here.
func _on_cells_cleared(board: GridState, cells: Array[Vector2i]) -> void:
	_resolve_clear(board, cells, false)

func _on_path_cleared(board: GridState, cells: Array[Vector2i]) -> void:
	_resolve_clear(board, cells, true)

# Fires the ON_CLEAR rules over the popped batch — they bank resources, deal damage and charge warp. Runs
# once per cascade step with the cells about to be removed, so the kinds are still readable on the board.
func _resolve_clear(board: GridState, cells: Array[Vector2i], is_path: bool) -> void:
	# Track the biggest match (across cascade steps) for the extra-turn rule. Match size is the one shared
	# measure — see _largest_match — counting a bent match whole, a path by its length.
	_move_max_run = maxi(_move_max_run, _largest_match(board, cells, is_path))
	if _encounter == null:
		return
	var active: int = _encounter.active_combatant()
	# Geometry the ON_CLEAR rules need: per-kind counts, the averaged centre of each kind (for popups), the
	# damage cells (for the fly-to-portrait), and the warp bars this batch earns.
	var counts: Dictionary[int, int] = {}
	var sums: Dictionary[int, Vector2] = {}
	var damage_cells: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var kind: int = _kind_at(board, cell.x, cell.y)
		counts[kind] = counts.get(kind, 0) + 1
		sums[kind] = sums.get(kind, Vector2.ZERO) + _cell_center(cell)
		if kind == _DAMAGE_KIND:
			damage_cells.append(cell)
	var centers: Dictionary[int, Vector2] = {}
	for kind: int in counts:
		centers[kind] = sums[kind] / float(counts[kind])
	var warp_bars: int = 0
	if counts.has(_WARP_KIND):
		var warp_cells: Array[Vector2i] = []
		for cell: Vector2i in cells:
			if _kind_at(board, cell.x, cell.y) == _WARP_KIND:
				warp_cells.append(cell)
		warp_bars = maxi(0, _largest_match(board, warp_cells, is_path) - 2)
	# Hand it all to the ON_CLEAR rules — they bank resources, deal damage and charge warp, then emit the
	# visual events. The host renders those below (a Resource rule can't spawn scene nodes).
	var ctx := MatchRuleContext.new(board)
	ctx.encounter = _encounter
	ctx.combatant = active
	ctx.counts = counts
	ctx.centers = centers
	ctx.damage_cells = damage_cells
	ctx.warp_bars = warp_bars
	ctx.scoring = rules.scoring if rules != null else null
	ctx.wallet = _wallet()
	ctx.actor_stats = _effective_stats(active)
	_run_phase(MatchPhase.ON_CLEAR, ctx)
	_render_clear_visuals(ctx)

# Renders the visual events the ON_CLEAR rules emitted: resource / warp popups, and the damage fly plus its
# delayed hit number. The rules mutate state; the host owns the scene nodes, so visuals come back via the context.
func _render_clear_visuals(ctx: MatchRuleContext) -> void:
	var struck: bool = false
	var charged: bool = false
	for visual: Dictionary in ctx.visuals:
		match visual.get("type", ""):
			"resource":
				var kind: int = visual["kind"]
				var amount: int = visual["amount"]
				var center: Vector2 = visual["center"]
				_spawn_match_popup(kind, amount, center)
			"warp":
				charged = true
				var bars: int = visual["bars"]
				var warp_center: Vector2 = visual["center"]
				_spawn_match_popup(_WARP_KIND, bars, warp_center)
			"damage":
				struck = true
				var target: int = visual["target"]
				var damage_cells: Array[Vector2i] = visual["cells"]
				var result: int = visual["result"]
				var dealt: int = visual["dealt"]
				# The damage flies from the match to the struck portrait; the result (or "Dodged!") lands with it.
				_fly_damage_to_portrait(damage_cells, target)
				_spawn_portrait_popup_delayed(_portrait_for(target), _damage_text(result, dealt), MatchTile.color_of(_DAMAGE_KIND), _FLY_DURATION)
	if struck:
		_refresh_health()
	if charged:
		_refresh_warp()

# The player's wallet state from the running game, or null when there's no game state.
func _wallet() -> WalletState:
	return GameSession.game_state.wallet if GameSession.game_state != null else null

# A match's reward for clearing [param count] tiles of a kind, per the encounter's [member MatchRules.scoring]
# formula (one-to-one by default; a [FibonacciScoringFormula] makes bigger matches pay super-linearly). Falls
# back to one-to-one when no formula is set.
func _reward_for(count: int) -> int:
	return rules.scoring.reward_for(count) if rules.scoring != null else maxi(0, count)

# Adds matched scrap to the player's wallet (a no-op when there's no wallet).
func _earn_scrap(amount: int) -> void:
	if GameSession.game_state != null and GameSession.game_state.wallet != null:
		GameSession.game_state.wallet.earn(amount)

#region Abilities

# Wires the scene's buttons to the encounter's abilities, left to right. Extra buttons (more than there
# are abilities) hide; the affordability pass runs once so they start in the right state.
func _setup_abilities() -> void:
	_ability_buttons.clear()
	# The bar shows the player ship's abilities (its hull kit + module abilities) — the player is who clicks it.
	_player_abilities = _ship_abilities(EncounterState.Combatant.PLAYER)
	var buttons: Array[Node] = _actions.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		if button == null:
			continue
		if i < _player_abilities.size():
			_configure_ability_button(button, _player_abilities[i])
			button.pressed.connect(_on_ability_pressed.bind(_player_abilities[i]))
			_ability_buttons.append(button)
		else:
			button.visible = false
	_refresh_abilities()

# Lays out one ability button: the cost gem and its count over the ability's name. Built in code so the
# button stays data-driven off the rules. The content ignores the mouse so the whole button stays clickable.
func _configure_ability_button(button: Button, ability: MatchAbility) -> void:
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.tooltip_text = "%s — %s (%s)" % [ability.ability_name, ability.describe(), _cost_text(ability)]

	# A full-width padded column, so a long ability name can wrap to the button width rather than clip.
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 6)
	pad.add_theme_constant_override("margin_right", 6)
	button.add_child(pad)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	pad.add_child(column)

	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 6)
	column.add_child(cost_row)

	if ability.costs.is_empty():
		# A free ability still gets a label so the button isn't blank above its name.
		var free_label := Label.new()
		free_label.text = "Free"
		free_label.add_theme_font_size_override("font_size", 26)
		cost_row.add_child(free_label)
	else:
		# One gem + count per cost, joined with a "+" so a multi-tile price reads at a glance.
		for i: int in ability.costs.size():
			var cost: AbilityCost = ability.costs[i]
			if i > 0:
				var plus := Label.new()
				plus.text = "+"
				plus.add_theme_font_size_override("font_size", 22)
				cost_row.add_child(plus)
			var icon := TileIcon.new()
			icon.kind = cost.kind
			icon.custom_minimum_size = Vector2(30, 30)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_row.add_child(icon)
			var cost_label := Label.new()
			cost_label.text = str(cost.amount)
			cost_label.add_theme_font_size_override("font_size", 26)
			cost_row.add_child(cost_label)

	var name_label := Label.new()
	name_label.text = ability.ability_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.70, 0.75, 0.88))
	column.add_child(name_label)

# Repaints each ability button from the player's gems and whose turn it is: usable ones (affordable, on the
# player's turn) light up in the gem color and stay pressable; the rest are disabled and dimmed. Abilities
# end the turn, so they're only usable on the player's own turn. A no-op until the buttons are wired in _ready.
func _refresh_abilities() -> void:
	var can_act: bool = _is_player_turn() and not _game_over and not _resolving
	for i: int in _ability_buttons.size():
		var ability: MatchAbility = _player_abilities[i]
		var usable: bool = can_act and _affordable(EncounterState.Combatant.PLAYER, ability)
		var button: Button = _ability_buttons[i]
		button.disabled = not usable
		_style_ability_button(button, _primary_cost_kind(ability), usable)

# Swaps the button's box for the affordable look (a bright border in the gem color) or the idle look
# (dim, faint border). Disabled buttons show the idle box; affordable ones show the lit box.
func _style_ability_button(button: Button, gem_kind: int, affordable: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	if affordable:
		# A free ability (no cost kind) lights up neutral white rather than a tile color.
		var gem: Color = MatchTile.color_of(gem_kind) if gem_kind >= 0 else Color.WHITE
		style.bg_color = Color(gem.r, gem.g, gem.b, 0.22)
		style.set_border_width_all(3)
		style.border_color = gem
	else:
		style.bg_color = Color(0.12, 0.13, 0.21, 0.6)
		style.set_border_width_all(1)
		style.border_color = Color(1, 1, 1, 0.08)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)

# A tapped ability button: the player uses it, but only on their own turn (abilities end the turn, so
# they're off-limits during the opponent's). A stale tap off-turn does nothing.
func _on_ability_pressed(ability: MatchAbility) -> void:
	if not _is_player_turn():
		return
	_use_ability(EncounterState.Combatant.PLAYER, ability)

# Uses [param ability] for [param combatant]: spends every one of its costs from that combatant's tally,
# applies each of its effects in order, then ends the turn and lets the next combatant act. Shared by the
# player's button and the AI opponent. Guarded so a stale call (no encounter, can't afford) does nothing.
# (Keeping the turn is no longer a flag on the ability — that'll come from a future extra-turn effect.)
func _use_ability(combatant: int, ability: MatchAbility) -> void:
	if _encounter == null or _game_over or _resolving or not _affordable(combatant, ability):
		return
	_resolving = true  # freezes input and the buttons until the action finishes resolving
	for cost: AbilityCost in ability.costs:
		_encounter.spend_resource(combatant, cost.kind, cost.amount)
	_apply_ability_effect(combatant, ability)
	_refresh_portraits()
	_message = "%s used %s." % [_name_for(combatant), ability.ability_name]
	_compose_status()
	# An attacking ability may have decided the encounter; stop before handing the turn over.
	if _check_for_end():
		_resolving = false
		return
	# Let the effects and their animation play out before the turn passes — don't hand over mid-resolve.
	await _settle_action()
	_resolving = false
	_advance_turn()
	# If that handed the board to the AI opponent, set it playing; if it's the player's turn, this no-ops.
	_take_opponent_turn_if_needed()

# Waits out the action beat so an ability's effect and animation finish before the turn passes. Zero in tests.
func _settle_action() -> void:
	if action_resolve_delay > 0.0:
		await get_tree().create_timer(action_resolve_delay).timeout

# Applies each of an ability's effects for the combatant using it, in order. The health/tally changes land
# here; the caller refreshes the HUD and resolves the turn.
func _apply_ability_effect(combatant: int, ability: MatchAbility) -> void:
	for effect: AbilityEffect in ability.effects:
		if effect != null:
			_apply_effect(combatant, effect)

# Applies one [AbilityEffect], dispatched by its type — each effect carries its own parameters (no shared
# magnitude). A new effect kind slots in as a new [AbilityEffect] subclass plus a branch here.
func _apply_effect(combatant: int, effect: AbilityEffect) -> void:
	var user_portrait: Control = _portrait_for(combatant)
	var foe: int = _encounter.opponent_of(combatant)
	if effect is ShieldEffect:
		var shield: int = (effect as ShieldEffect).amount
		_encounter.add_shield(combatant, shield)
		_refresh_health()
		_spawn_portrait_popup(user_portrait, "+%d shield" % shield, MatchTile.color_of(3))
	elif effect is DodgeEffect:
		_encounter.set_dodge(combatant, true)
		_spawn_portrait_popup(user_portrait, "Evading", MatchTile.color_of(1))
	elif effect is DrainEffect:
		_drain_resources(foe, (effect as DrainEffect).amount)
		_spawn_portrait_popup(_portrait_for(foe), "Drained", MatchTile.color_of(2))
	elif effect is DamageBuffEffect:
		_encounter.add_buff(combatant, Stat.Type.DAMAGE, (effect as DamageBuffEffect).amount)
		_spawn_portrait_popup(user_portrait, "Damage +%d" % (effect as DamageBuffEffect).amount, MatchTile.color_of(0))
	elif effect is DisableEffect:
		_disable_opponent_module(foe, (effect as DisableEffect).turns)
		_spawn_portrait_popup(_portrait_for(foe), "Disabled", MatchTile.color_of(2))
	elif effect is AttackEffect:
		var dealt: int = (effect as AttackEffect).amount
		var result: int = _encounter.deal_damage(foe, dealt)
		_refresh_health()
		_fly_attack_glyphs(combatant, foe, clampi(dealt, 1, 5))
		_spawn_portrait_popup_delayed(_portrait_for(foe), _damage_text(result, dealt), MatchTile.color_of(_DAMAGE_KIND), _FLY_DURATION)

# Removes [param amount] from each of [param combatant]'s four stat resources — the Siphon drain.
func _drain_resources(combatant: int, amount: int) -> void:
	for kind: int in _STAT_KINDS:
		_encounter.spend_resource(combatant, kind, amount)

# Disables one of [param target]'s still-active modules for [param turns] turns — disabling one of its cells
# deactivates the whole module, so it stops counting toward [param target]'s stats until it re-enables. Picks
# the module from the board's seeded RNG so it's reproducible; a no-op when the target has no grid or every
# module is already down.
func _disable_opponent_module(target: int, turns: int) -> void:
	var grid: ModuleGridState = _grid_of(_starship_for(target))
	if grid == null:
		return
	var disabled: Array[Vector2i] = _encounter.disabled_cells_of(target)
	var live: Array[ModuleState] = []
	for module_state: ModuleState in grid.modules:
		if module_state.blueprint != null and grid.enabled(module_state, disabled) and not grid.cells_of(module_state).is_empty():
			live.append(module_state)
	if live.is_empty():
		return
	var pick: ModuleState = live[_rng.randi_range(0, live.size() - 1)]
	_encounter.disable_cell(target, grid.cells_of(pick)[0], turns)

# The popup text for an attack: "Dodged!" when the target evaded it (result < 0), else the damage dealt.
func _damage_text(result: int, dealt: int) -> String:
	return "Dodged!" if result < 0 else "%d damage" % dealt

# Whether [param combatant] holds enough matched tiles to pay every one of [param ability]'s costs. A
# cost-less (free) ability is always affordable.
func _affordable(combatant: int, ability: MatchAbility) -> bool:
	if _encounter == null:
		return false
	for cost: AbilityCost in ability.costs:
		if cost != null and _encounter.resource_of(combatant, cost.kind) < cost.amount:
			return false
	return true

# The most expensive affordable ability for [param combatant] (summed cost as an impact proxy), or null if
# none is affordable — the AI opponent's ability pick. A dodge already armed is skipped, so the opponent spends
# its turn attacking (or arming something else) instead of refreshing a dodge that would otherwise feel permanent.
func _best_affordable_ability(combatant: int) -> MatchAbility:
	var best: MatchAbility = null
	var best_cost: int = -1
	for ability: MatchAbility in _ship_abilities(combatant):
		if _arms_dodge(ability) and _encounter != null and _encounter.dodge_of(combatant):
			continue
		if not _affordable(combatant, ability):
			continue
		var total: int = _total_cost(ability)
		if best == null or total > best_cost:
			best = ability
			best_cost = total
	return best

# Whether [param ability] arms a dodge — keeps the AI from re-casting a dodge it already has.
func _arms_dodge(ability: MatchAbility) -> bool:
	for effect: AbilityEffect in ability.effects:
		if effect is DodgeEffect:
			return true
	return false

# The summed tile cost of [param ability] — the AI's crude impact proxy when picking what to play.
func _total_cost(ability: MatchAbility) -> int:
	var total: int = 0
	for cost: AbilityCost in ability.costs:
		if cost != null:
			total += cost.amount
	return total

# The kind of [param ability]'s first cost (for the button's accent color), or -1 when the ability is free.
func _primary_cost_kind(ability: MatchAbility) -> int:
	return ability.costs[0].kind if not ability.costs.is_empty() else -1

# A one-line price for the tooltip — "10 red + 12 green", or "Free" when the ability has no costs.
func _cost_text(ability: MatchAbility) -> String:
	if ability.costs.is_empty():
		return "Free"
	var parts: Array[String] = []
	for cost: AbilityCost in ability.costs:
		parts.append("%d %s" % [cost.amount, _kind_name(cost.kind)])
	return " + ".join(parts)

# Whether it's the player's turn (or there's no encounter, e.g. the standalone scene — then always theirs).
func _is_player_turn() -> bool:
	return _encounter == null or _encounter.active_combatant() == EncounterState.Combatant.PLAYER

#endregion

#region Warp & Jump

# Sets the encounter's warp mode for this board: Quick Match runs warp as a two-way tug (the opponent can win
# on it too), Campaign as a one-way meter the opponent only drains. Seeds each side's warp capacity from its
# ship's warp-core modules, so the warp bar is sized by what a ship carries rather than a fixed constant.
func _configure_warp() -> void:
	if _encounter == null:
		return
	_encounter.warp_tug = quick_match
	_encounter.player_warp_max = _warp_capacity_of(EncounterState.Combatant.PLAYER)
	_encounter.opponent_warp_max = _warp_capacity_of(EncounterState.Combatant.OPPONENT)

# Fills both fight ships to full hull at the start of an encounter — max is the ship's own derived hull (base
# health stat plus any hull modules), so HP is ship-driven. A side with no ship (the standalone scene) is skipped.
func _configure_health() -> void:
	if _encounter == null:
		return
	for combatant: int in [EncounterState.Combatant.PLAYER, EncounterState.Combatant.OPPONENT]:
		var ship: StarshipState = _starship_for(combatant)
		if ship != null:
			ship.health = ship.max_health()

# [param combatant]'s warp capacity — the warp_capacity their slotted modules sum to (a disabled core stops
# counting, like any module). Zero means the ship carries no warp core and can't warp.
func _warp_capacity_of(combatant: int) -> int:
	return _effective_stats(combatant).warp_capacity

# Whether warp is in play this board: the WarpRule must be ruled in and enabled, and at least one ship must
# carry a warp core — if neither can warp, there's nothing to charge, so warp tiles don't spawn and no meter
# is built.
func _warp_active() -> bool:
	var rule := _find_warp_rule()
	if rule == null or not rule.enabled:
		return false
	return _encounter != null and (_encounter.player_warp_max > 0 or _encounter.opponent_warp_max > 0)

# The active WarpRule in the encounter's ruleset, or null if warp isn't ruled in — its enabled flag is the
# match-level warp switch (see [method _warp_active]).
func _find_warp_rule() -> WarpRule:
	if rules == null or rules.ruleset == null:
		return null
	for rule: Rule in rules.ruleset.rules:
		if rule is WarpRule:
			return rule as WarpRule
	return null

# Builds the warp meter once, the first time warp is active for this board — the capacity isn't known until a
# session binds its ships, so the bar can't be built unconditionally in _ready like the rest of the HUD.
func _ensure_warp_bar() -> void:
	if _warp_segments.is_empty() and _warp_active():
		_build_warp_bar()

# The most segments the meter ever needs: the larger of the two sides' capacities, since the bar shows the
# leader's capacity and the lead can swing either way.
func _max_warp_segments() -> int:
	if _encounter == null:
		return 0
	return maxi(_encounter.player_warp_max, _encounter.opponent_warp_max)

# Listens for [signal Resource.changed] on the current encounter so a Debug-panel edit (the stat editor's
# health/stat sliders) repaints the live readouts at once rather than waiting for the next move.
func _watch_encounter() -> void:
	if _encounter != null and not _encounter.changed.is_connected(_on_encounter_changed):
		_encounter.changed.connect(_on_encounter_changed)

func _on_encounter_changed() -> void:
	_refresh_health()
	_refresh_warp()
	_refresh_jump()

# The encounter is the running game's, not this node's — drop the Debug panel's handle to it when the board
# leaves the tree (back to the menu) so the stat editor reads "no encounter" instead of a stale one.
func _exit_tree() -> void:
	if DebugConfig.active_state == GameSession.game_state:
		DebugConfig.active_state = null

# Builds the warp meter — a row of [method _max_warp_segments] segment cells — and slots it into the layout
# immediately above the board. Filled by [method _refresh_warp] to show how charged the meter is, and how many
# of those cells the leading side's capacity actually uses.
func _build_warp_bar() -> void:
	var board_panel: Node = _canvas.get_parent() if _canvas != null else null
	if board_panel == null:
		return
	var body := board_panel.get_parent() as VBoxContainer
	if body == null:
		return
	var row := HBoxContainer.new()
	row.name = "WarpBar"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var caption := Label.new()
	caption.text = "WARP"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.66, 0.72, 0.85))
	row.add_child(caption)

	_warp_segments.clear()
	for _i: int in _max_warp_segments():
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(0, 20)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(seg)
		_warp_segments.append(seg)

	body.add_child(row)
	body.move_child(row, board_panel.get_index())  # sit immediately above the board
	_refresh_warp()

# Paints one warp segment: the leader's fill (bright, white-edged) when charged, a dim empty cell otherwise.
func _paint_warp_segment(seg: Panel, filled: bool, fill: Color) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	if filled:
		style.bg_color = fill
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.5)
	else:
		style.bg_color = Color(0.12, 0.13, 0.21, 0.6)
		style.set_border_width_all(1)
		style.border_color = Color(1, 1, 1, 0.08)
	seg.add_theme_stylebox_override("panel", style)

# Builds the "JUMP" call-to-action: a bold, warp-colored button low over the board, hidden until the player
# fills their warp meter. Pressing it wins the encounter (see [method _on_jump_pressed]).
func _build_jump_button() -> void:
	var button := Button.new()
	button.text = "JUMP"
	button.visible = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(220, 88)
	button.add_theme_font_size_override("font_size", 40)
	# Centered horizontally, sitting low so it reads as a "you can win now" prompt without burying the board.
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	button.offset_bottom = -140.0
	var warp_color: Color = MatchTile.color_of(_WARP_KIND)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(warp_color.r, warp_color.g, warp_color.b, 0.9)
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = Color.WHITE
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(_on_jump_pressed)
	add_child(button)
	_jump_button = button

# Shows the Jump button only when the player has filled their warp and can cash it in — and not mid-resolve or
# after the encounter's been decided.
func _refresh_jump() -> void:
	if _jump_button == null:
		return
	_jump_button.visible = _encounter != null and not _game_over and not _resolving and _encounter.can_jump(EncounterState.Combatant.PLAYER)

# The player taps Jump: expend the full warp meter and win the encounter outright. Guarded so a stale tap
# (no full meter, game over, mid-resolve) does nothing.
func _on_jump_pressed() -> void:
	if _encounter == null or _game_over or _resolving or not _encounter.can_jump(EncounterState.Combatant.PLAYER):
		return
	_encounter.jump(EncounterState.Combatant.PLAYER)
	_message = "%s jumped to warp — clear of the fight!" % _name_for(EncounterState.Combatant.PLAYER)
	_compose_status()
	_refresh_portraits()
	_check_for_end()

#endregion

#region Popups

# The center of a board cell in the view's local pixel space (the grid is anchored at the origin).
func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * _CELL_SIZE

# A floating popup for a cleared kind: "+N <name>" for resources (damage is shown by flying tiles instead),
# colored by the gem.
func _spawn_match_popup(kind: int, count: int, center_local: Vector2) -> void:
	if _popup_layer == null or _view == null:
		return
	var text: String = "%d damage" % count if kind == _DAMAGE_KIND else "+%d %s" % [count, _kind_name(kind)]
	_emit_popup(_view.to_global(center_local), text, MatchTile.color_of(kind))

# A floating popup centered over a portrait — used for ability hits, which have no board cell.
func _spawn_portrait_popup(portrait: Control, text: String, color: Color) -> void:
	if _popup_layer == null or portrait == null:
		return
	_emit_popup(portrait.get_global_rect().get_center(), text, color)

func _emit_popup(global_pos: Vector2, text: String, color: Color) -> void:
	var popup := FloatingText.new()
	_popup_layer.add_child(popup)
	popup.global_position = global_pos
	popup.setup(text, color)

# Same as [method _spawn_portrait_popup] but after [param delay] seconds — so a damage number lands when the
# tiles that carry it reach the portrait. Bails if the board tears down before the delay elapses.
func _spawn_portrait_popup_delayed(portrait: Control, text: String, color: Color, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	_spawn_portrait_popup(portrait, text, color)

# Flings one damage-tile glyph per cleared damage cell at the struck portrait — the "the match throws its
# damage at them" beat. Purely cosmetic; the hit already landed.
func _fly_damage_to_portrait(cells: Array[Vector2i], target_combatant: int) -> void:
	var portrait: Control = _portrait_for(target_combatant)
	if _view == null or portrait == null:
		return
	var target: Vector2 = portrait.get_global_rect().get_center()
	for i: int in cells.size():
		_fly_glyph(_view.to_global(_cell_center(cells[i])), target, i * _FLY_STAGGER)

# Flings a few damage glyphs from the attacker portrait to the target — the version used when an ability
# deals the damage, since an ability has no board cells of its own.
func _fly_attack_glyphs(from_combatant: int, to_combatant: int, count: int) -> void:
	var from_portrait: Control = _portrait_for(from_combatant)
	var to_portrait: Control = _portrait_for(to_combatant)
	if from_portrait == null or to_portrait == null:
		return
	var from: Vector2 = from_portrait.get_global_rect().get_center()
	var target: Vector2 = to_portrait.get_global_rect().get_center()
	for i: int in count:
		_fly_glyph(from, target, i * _FLY_STAGGER)

# Sends a single damage glyph from one screen point to another: it launches fast, holds full size across
# the trip, then pops (shrinks + fades) as it lands, and frees itself. The visible half of "dealing damage".
func _fly_glyph(from_global: Vector2, to_global: Vector2, delay: float) -> void:
	if _popup_layer == null:
		return
	var glyph := MatchTile.new()
	glyph.kind = _DAMAGE_KIND
	glyph.scale = Vector2(_FLY_TILE_PX, _FLY_TILE_PX)
	glyph.modulate.a = 0.0 if delay > 0.0 else 1.0  # staggered glyphs stay hidden until their turn
	_popup_layer.add_child(glyph)
	glyph.global_position = from_global
	var tween: Tween = glyph.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_property(glyph, "modulate:a", 1.0, 0.01)
	# Launch and travel — fast off the mark, easing in as it nears the portrait, growing a touch on the way.
	tween.tween_property(glyph, "global_position", to_global, _FLY_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(glyph, "scale", Vector2(_FLY_TILE_PX, _FLY_TILE_PX) * 1.25, _FLY_DURATION).set_ease(Tween.EASE_IN)
	# Impact pop at the portrait.
	tween.tween_property(glyph, "scale", Vector2.ZERO, _FLY_POP).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(glyph, "modulate:a", 0.0, _FLY_POP)
	tween.tween_callback(glyph.queue_free)

# The portrait belonging to a combatant (the player's on the left, the opponent's on the right).
func _portrait_for(combatant: int) -> PortraitPanel:
	return _player_portrait if combatant == EncounterState.Combatant.PLAYER else _opponent_portrait

# A kind's display name, clamped to the catalog.
func _kind_name(kind: int) -> String:
	return MatchTile.NAMES[clampi(kind, 0, MatchTile.NAMES.size() - 1)]

#endregion

#region Reshuffle & move count

# Drops the whole board off the bottom, regenerates it, and pours a fresh one in — the dead-board reset.
# Sets the "No moves" message and waits out the rebuild so the board is playable before returning.
func _reshuffle_board() -> void:
	_reshuffling = true
	# Split the dead board's tiles between the combatants before it's swept away (the rule may be off).
	_split_board_resources()
	_message = "No moves — board split, reshuffling."
	_compose_status()
	await _match_view.drop_out()
	_session.regenerate()  # rebuilds the tiles and (via _on_regenerated) drops them in
	while _match_view.is_busy():
		await get_tree().process_frame
	_reshuffling = false
	_refresh_move_debug()

# Divides every tile on the current board between the two combatants as resources, each taking the floor of
# half a kind's count (the odd tile is discarded). Banks the four stat kinds into both tallies and scrap into
# the player's wallet; damage and warp aren't bankable resources, so they're left out. A no-op when the
# rule is off. Players call this a stalemate payout — the board you couldn't clear isn't simply lost.
func _split_board_resources() -> void:
	if not rules.reload_splits_resources or _encounter == null or _session == null:
		return
	var board: GridState = _session.state
	if board == null:
		return
	var counts: Dictionary[int, int] = {}
	for y: int in config.board_height:
		for x: int in config.board_width:
			var kind: int = _kind_at(board, x, y)
			if kind >= 0:
				counts[kind] = counts.get(kind, 0) + 1
	for kind: int in counts:
		var each: int = counts[kind] / 2  # floor; the odd leftover tile is discarded
		if each <= 0:
			continue
		match kind:
			_SCRAP_KIND:
				_earn_scrap(each)  # only the player banks scrap (the opponent has no wallet)
			_DAMAGE_KIND, _WARP_KIND:
				pass  # neither damage nor warp is a banked resource
			_:
				_encounter.add_resource(EncounterState.Combatant.PLAYER, kind, each)
				_encounter.add_resource(EncounterState.Combatant.OPPONENT, kind, each)
	_refresh_portraits()

# Whether the board has a move to play. Unknown for non-swap modes (no cheap test) counts as "yes", so only
# a confirmed dead swap board reshuffles.
func _has_moves() -> bool:
	return _available_moves() != 0

# Count of adjacent swaps that would make a match, or -1 when there's no cheap way to know (non-swap modes).
func _available_moves() -> int:
	if input_mode != MatchBoardView.InputMode.SWAP or _session == null or _session.state == null:
		return -1
	var swap := _session.find_interaction(GridInteraction.Gesture.SWIPE) as SwapInteraction
	if swap == null:
		return -1
	return SwapSolver.count_moves(_session.state, swap)

# Builds the debug move-count chip: monospace on a flat-blue panel at the top center, deliberately ugly so
# it's obvious it's debug-only. Delete this call (and _refresh_move_debug's) to remove it.
func _build_move_debug() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centered on its own width at the very top (anchors at 0.5 + grow-both is the self-sizing-centered idiom).
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_top = 8
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.9)  # flat blue — a "remove me" color
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Courier New", "monospace"])
	label.add_theme_font_override("font", mono)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.text = "moves: ?"
	panel.add_child(label)
	add_child(panel)
	_move_debug_label = label

# Updates the debug chip with the live move count ("n/a" for modes without a count).
func _refresh_move_debug() -> void:
	if _move_debug_label == null:
		return
	var moves: int = _available_moves()
	_move_debug_label.text = "moves: %d" % moves if moves >= 0 else "moves: n/a"

#endregion

#region End state

# Ends the encounter if a combatant has fallen: in Quick Match, freezes play and shows the win/lose overlay
# with a Restart. Returns true when the encounter is over, so callers stop handing the turn around.
func _check_for_end() -> bool:
	if _encounter == null or not _encounter.is_over():
		return false
	# Fire the VICTORY / DEFEAT phases once, when the encounter first ends, naming each combatant.
	if not _ended:
		_ended = true
		var loser: int = _encounter.defeated()
		var winner: int = _encounter.opponent_of(loser)
		var win_ctx := _phase_context()
		win_ctx.combatant = winner
		_run_phase(MatchPhase.VICTORY, win_ctx)
		var lose_ctx := _phase_context()
		lose_ctx.combatant = loser
		_run_phase(MatchPhase.DEFEAT, lose_ctx)
	if quick_match and not _game_over:
		_game_over = true
		_refresh_abilities()
		_show_end_overlay()
	return true

# Builds the full-screen win/lose overlay: a dimmer, the verdict, and a Restart button. Player down → GAME
# OVER; opponent down → YOU WIN. The overlay eats input so the frozen board underneath can't be touched.
func _show_end_overlay() -> void:
	if _end_overlay != null:
		return
	var player_won: bool = _encounter.defeated() == EncounterState.Combatant.OPPONENT
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.09, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)

	var title := Label.new()
	title.text = "YOU WIN" if player_won else "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.52, 0.86, 0.60) if player_won else Color(0.88, 0.40, 0.42))
	column.add_child(title)

	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(240, 76)
	restart.add_theme_font_size_override("font_size", 32)
	restart.pressed.connect(_restart_encounter)
	column.add_child(restart)

	add_child(overlay)
	_end_overlay = overlay

# Restarts the Quick Match on a fresh board: clears the overlay, resets the encounter and both tallies, and
# pours in a new board. Wired to the overlay's Restart button. (Campaign would replace this with its own flow.)
func _restart_encounter() -> void:
	# A fresh encounter (full health, no shields, zero resources) — a new [Encounter] node and state, not a
	# hand-reset of fields. The host owns the encounter, so ask it to reopen one and re-read the result; when
	# standalone (no host) the match reopens its own fallback.
	if _fallback_encounter != null:
		_open_fallback_encounter()
	else:
		restart_requested.emit()
		_encounter = GameSession.game_state.encounter
	_watch_encounter()
	_restart_board()

# Starts the match over on a fresh board against the current [member _encounter]: clears the end overlay and
# the game-over flags, regenerates the board, and re-runs SETUP. The overlay's Restart makes a fresh encounter
# first ([method _restart_encounter]); the shell's Restart binds one in ([method bind_session]) — both land here.
func _restart_board() -> void:
	_hide_end_overlay()
	_game_over = false
	_ended = false
	_resolving = false
	_configure_warp()
	_move_max_run = 0
	_session.regenerate()  # fresh board, drops in via _on_regenerated
	_refresh_portraits()
	_refresh_turn_tracker()
	_refresh_move_debug()
	_message = _prompt_for_mode()
	_compose_status()
	_run_phase(MatchPhase.SETUP, _phase_context())  # a fresh match is set up — let SETUP rules seed it

func _hide_end_overlay() -> void:
	if _end_overlay != null:
		_end_overlay.queue_free()
		_end_overlay = null

#endregion

# Repaints the top row (round, turn-of-round, whose turn) and highlights the active portrait.
func _refresh_turn_tracker() -> void:
	# Whose turn it is decides which selection rule the board plays by — re-sync before repainting.
	_sync_selection()
	if _encounter == null:
		return
	if _round_label != null:
		_round_label.text = "ROUND %d" % _encounter.round_number
	if _turn_label != null:
		var who: String = _name_for(_encounter.active_combatant()).to_upper()
		_turn_label.text = "TURN %d / %d · %s" % [_encounter.turn_in_round, EncounterState.TURNS_PER_ROUND, who]
	if _player_portrait != null:
		_player_portrait.set_active(_encounter.active_combatant() == EncounterState.Combatant.PLAYER)
	if _opponent_portrait != null:
		_opponent_portrait.set_active(_encounter.active_combatant() == EncounterState.Combatant.OPPONENT)
	# A turn change can expire a dodge (the owner's turn coming back around) — keep the badges in step.
	_refresh_dodge()
	# Ability buttons depend on whose turn it is (they end the turn), so refresh them when the turn flips.
	_refresh_abilities()

#region Rules

# Runs every rule registered for [param phase] against [param context] — the host firing one phase of play
# (see [MatchPhase]) across the effective ruleset: the match's defaults with the acting ship's rules layered
# over them, so a phase fires the union of match + ship (+ module) rules, the ship's winning on conflict.
func _run_phase(phase: StringName, context: MatchRuleContext) -> void:
	_effective_ruleset(context.combatant).run(phase, context)

# The match-scope ruleset with the acting ship's rules layered over it — the same default + per-ship override
# that selection uses (see [method _active_selection]). A ship rule replaces a match rule of the same
# [member Rule.rule_name] (override), else adds to the set. Rebuilt per phase run: cheap, and always current
# with the acting ship and its enabled modules.
func _effective_ruleset(combatant: int) -> Ruleset:
	var composed := Ruleset.new()
	if rules != null and rules.ruleset != null:
		for rule: Rule in rules.ruleset.rules:
			composed.add(rule)
	for rule: Rule in _ship_rules(combatant):
		if rule == null:
			continue
		if rule.rule_name != &"":
			composed.remove_named(rule.rule_name)
		composed.add(rule)
	return composed

# A minimal context for a lifecycle phase (no per-clear payload): the encounter and the active combatant.
func _phase_context() -> MatchRuleContext:
	var ctx := MatchRuleContext.new(_session.state if _session != null else null)
	ctx.encounter = _encounter
	ctx.combatant = _encounter.active_combatant() if _encounter != null else -1
	return ctx

# Centralised turn handover: fire TURN_END for the mover, advance, repaint, then fire TURN_START for the new
# mover — so turn-scoped rules (board rotation, draws, …) hook the boundary in one place.
func _advance_turn() -> void:
	if _encounter == null:
		return
	_run_phase(MatchPhase.TURN_END, _phase_context())
	_encounter.advance_turn()
	_refresh_turn_tracker()
	_run_phase(MatchPhase.TURN_START, _phase_context())

#endregion

#region Selection rules

# The starship acting this turn (the player's, or the opponent's on its turn). Null-safe for the
# standalone scene with no bound game.
func _active_starship() -> StarshipState:
	if _encounter != null and _encounter.active_combatant() == EncounterState.Combatant.OPPONENT:
		return _opponent_starship()
	return _player_starship()

# The selection rule in force this turn: the active ship's override wins, else the encounter's default,
# else the legacy-export fallback. Never null once _ready has run.
func _active_selection() -> SelectionRule:
	var ship: StarshipState = _active_starship()
	if ship != null and ship.selection_override != null:
		return ship.selection_override
	if rules != null and rules.default_selection != null:
		return rules.default_selection
	return _fallback

# Re-points the board at the active turn's selection rule, but only when it actually changed — so a board
# whose combatants share one rule never churns the view, while differing per-ship rules switch on the turn.
func _sync_selection() -> void:
	if _session == null or _match_view == null:
		return
	var selection: SelectionRule = _active_selection()
	if selection == null or selection == _applied_selection:
		return
	_apply_selection(selection)
	_applied_selection = selection

# Applies a selection rule live: enables exactly its interaction, retunes adjacency / run length / range on
# every verb and match condition, and re-points the view's input handling. No board rebuild — the verbs all
# live in the session already (see [MatchBlueprint]); this just flips which one is live.
func _apply_selection(rule: SelectionRule) -> void:
	if rule == null or _session == null:
		return
	var mode: MatchBoardView.InputMode = rule.input_mode()
	for interaction: GridInteraction in _session.interactions:
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
	for condition: MatchLineCondition in _session.find_rules(MatchLineCondition):
		condition.diagonal = rule.allow_diagonal
		condition.min_run_length = rule.min_run
	if _match_view != null:
		_match_view.refresh_mode(mode)
	# Mirror onto the cached fields the rest of the screen reads (the prompt, the AI gate, the debug chip).
	input_mode = mode
	allow_diagonal = rule.allow_diagonal

#endregion

# The display name of the combatant whose turn it currently is.
func _active_name() -> String:
	if _encounter == null:
		return _player_portrait.portrait_name
	return _name_for(_encounter.active_combatant())

func _name_for(combatant: EncounterState.Combatant) -> String:
	if combatant == EncounterState.Combatant.OPPONENT:
		return _opponent_portrait.portrait_name
	return _player_portrait.portrait_name

## The how-to-play line for the active input mode.
func _prompt_for_mode() -> String:
	match input_mode:
		MatchBoardView.InputMode.CONNECT:
			return "Trace through %d+ matching tiles to clear them." % config.min_run
		MatchBoardView.InputMode.LINE_SHIFT:
			return "Slide a tile along a row or column to match %d." % config.min_run
		MatchBoardView.InputMode.TELEPORT:
			return "Tap a tile, then another, to swap them and match %d." % config.min_run
		_:
			return "Match %d in a row to clear." % config.min_run

func _make_tile(object: GridObjectState) -> Node2D:
	var tile := MatchTile.new()
	var tile_state := object as _TileState
	tile.kind = tile_state.kind if tile_state != null else 0
	return tile

func _spawn_tile(_board: GridState, cell: Vector2i) -> GridObjectState:
	var cells: Array[Vector2i] = [cell]
	return _TileState.new(cells, _pick_kind())

func _generate_board() -> GridState:
	var state := GridState.new(config.board_width, config.board_height, 1)
	# One stream feeds generation and refills.
	_rng.seed = _session.derive_seed("tiles")
	for y: int in config.board_height:
		for x: int in config.board_width:
			var cells: Array[Vector2i] = [Vector2i(x, y)]
			state.place_object(0, _TileState.new(cells, _pick_kind_avoiding_runs(state, x, y)))
	return state

# A weighted kind for a refill — the board is a generator, so it can't stall and a refill may roll a
# fresh match (the cascades). Weights come from the encounter [member rules].
func _pick_kind() -> int:
	return _weighted_choice(_all_kinds)

# A kind for cell (x, y) that doesn't complete a 3-run there, so a freshly generated board starts
# stable; weighted (per the rules) among the safe kinds.
func _pick_kind_avoiding_runs(state: GridState, x: int, y: int) -> int:
	var safe: Array[int] = []
	for kind: int in _KIND_COUNT:
		if not _would_complete_run(state, x, y, kind):
			safe.append(kind)
	if safe.is_empty():
		return _pick_kind()
	return _weighted_choice(safe)

# Roulette-wheel pick over [param candidates], each kind weighted by the rules' spawn weight and drawn
# from the board's seeded stream so generation stays reproducible. Falls back to a uniform pick when the
# candidates carry no weight at all.
func _weighted_choice(candidates: Array[int]) -> int:
	var table := _spawn_table()
	var total: int = 0
	for kind: int in candidates:
		var weight: int = table.get(kind, 0)
		total += weight
	if total <= 0:
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	var roll: int = _rng.randi_range(0, total - 1)
	for kind: int in candidates:
		var weight: int = table.get(kind, 0)
		roll -= weight
		if roll < 0:
			return kind
	return candidates[candidates.size() - 1]

# The board's spawn pool: the rules' composed spawn weights (each rule declares its own tiles), with warp
# forced off unless a ship can actually warp (rule on + a warp core). Rebuilt per refill, so a live rule edit
# — adding, dropping, or retuning a rule — reshapes the board immediately.
func _spawn_table() -> Dictionary:
	var table: Dictionary = rules.spawn_table() if rules != null else {}
	if not _warp_active():
		table[_WARP_KIND] = 0
	return table

func _would_complete_run(state: GridState, x: int, y: int, kind: int) -> bool:
	if x >= 2 and _kind_at(state, x - 1, y) == kind and _kind_at(state, x - 2, y) == kind:
		return true
	if y >= 2 and _kind_at(state, x, y - 1) == kind and _kind_at(state, x, y - 2) == kind:
		return true
	return false

func _kind_at(state: GridState, x: int, y: int) -> int:
	var tile := state.get_object_at(0, x, y) as _TileState
	if tile == null:
		return -1
	return tile.kind

# The one way a match's size is measured anywhere — extra turns, warp, all of it — so the shape rules are
# identical for every tile, never per type. How a match is sized depends only on how it was cleared, never on
# re-reading the board, because the same cells can be two different matches:
#   - is_path (a drag/trace clear): the traced path IS the match, so its size is the whole run of cells.
#   - line clears (swap / slide, and every cascade): a match is a straight run of [member SelectionRule.min_run]+;
#     runs that share a cell merge into one match; size is the distinct cells in the largest merged group. So
#     an L (3+3 sharing a corner) is 5 and a T (4+3) is 6, while a 3x2 block — two parallel runs sharing no
#     cell — stays two 3s, never a 6 (which a blind flood-fill would wrongly merge). Diagonal runs count only
#     when the active rule matches along them ([member allow_diagonal]).
# A 3x2 dragged whole is a 6; the same 3x2 swapped into place is a 3 — that's the whole reason for is_path.
func _largest_match(board: GridState, cells: Array[Vector2i], is_path: bool) -> int:
	if cells.is_empty():
		return 0
	if is_path:
		return cells.size()
	var kinds: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in cells:
		kinds[cell] = _kind_at(board, cell.x, cell.y)
	var selection: SelectionRule = _active_selection()
	var min_run: int = selection.min_run if selection != null else 3
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
				_union_cells(parent, run[0], run[index])
	var sizes: Dictionary[Vector2i, int] = {}
	var best: int = 1
	for cell: Vector2i in cells:
		var root: Vector2i = _find_cell(parent, cell)
		sizes[root] = sizes.get(root, 0) + 1
		best = maxi(best, sizes[root])
	return best

func _find_cell(parent: Dictionary[Vector2i, Vector2i], cell: Vector2i) -> Vector2i:
	var root: Vector2i = cell
	while parent[root] != root:
		root = parent[root]
	return root

func _union_cells(parent: Dictionary[Vector2i, Vector2i], a: Vector2i, b: Vector2i) -> void:
	var root_a: Vector2i = _find_cell(parent, a)
	var root_b: Vector2i = _find_cell(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a

func _on_regenerated() -> void:
	if _grid == null:
		return
	_canvas.recenter()
	await _match_view.drop_in()
	_refresh_move_debug()
	# Catch a freshly generated board that happens to have no moves — but not mid-reshuffle (it regenerates
	# too, and re-checking here would recurse).
	if not _reshuffling and not _has_moves():
		await _reshuffle_board()

#endregion

## Single-cell tile. `kind` doubles into `state["kind"]`, which is what [[MatchCondition]]'s default
## resolver matches on.
class _TileState extends GridObjectState:
	var kind: int

	func _init(occupied_cells: Array[Vector2i] = [], tile_kind: int = 0) -> void:
		super (occupied_cells)
		kind = tile_kind
		state["kind"] = tile_kind
