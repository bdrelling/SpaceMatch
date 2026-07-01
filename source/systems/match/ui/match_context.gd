class_name MatchContext
extends RefCounted
## The live shared state the [MatchGame] coordinator owns, handed to every collaborator so they reach the board,
## the encounter and each other through one object rather than a back-reference to the [MatchGame] Node. The
## coordinator populates this in its `_ready` and keeps [member encounter] current at each rebind; collaborators
## only read it (plus the sibling collaborator refs), never the coordinator.

#region Properties

# The encounter being rendered — reassigned on bind / fallback / restart, so it is kept current by the
# coordinator at each of those seams rather than captured once.
var encounter: EncounterState

# The match screen root ([MatchGame] itself) and the board canvas — so collaborators can parent screen-level UI
# (the warp bar, the Jump button) and reach the board's layout container without a back-ref to the coordinator.
var root: Control
var canvas: BoardCanvas

var session: GridSession
var view: GridView
var grid: Grid
var match_view: MatchBoardView
var popup_layer: Node2D
var player_portrait: PortraitPanel
var opponent_portrait: PortraitPanel
var round_label: Label
var turn_label: Label
var actions: HBoxContainer
var ruleset: Ruleset
var config: MatchConfig

# The board's cell size in pixels, so collaborators can map a cell to its centre without reaching the coordinator.
var cell_size: float = 64.0

# The input/adjacency knobs the selection engine writes and the rest of the screen reads (the prompt, the AI
# gate, the debug chip, match sizing). Mirrored here so no collaborator reaches back to the coordinator for them.
var input_mode: MatchBoardView.InputMode = MatchBoardView.InputMode.SWAP
var allow_diagonal: bool = false

# Sets the one-line status string (the coordinator's [code]status_text[/code] setter), so a collaborator can post
# a status line without reaching the coordinator. Wired in [method MatchGame._build_context].
var set_status: Callable = func(_text: String) -> void: pass

# Sibling collaborators, so each reaches the others through the context (a DAG — no collaborator holds the
# coordinator). Populated by the coordinator in `_ready` after each is constructed. Typed to their concrete
# classes as each is introduced; the rest stay at the shared [RefCounted] base until then. The board factory is
# a pure static utility, so it is not held here.
var popups: MatchPopups
var abilities: MatchAbilityBar
var rules: MatchRulesEngine
var readouts: MatchReadouts
var resolver: MatchClearResolver
var end_state: MatchEndState
var turn_loop: MatchTurnLoop

#endregion

#region Methods


# Snapshots [param game]'s live shared state into a fresh context and builds every collaborator against it (in
# dependency order). The popup layer isn't up yet — the coordinator fills [member popup_layer] once it exists —
# and [member encounter] is kept current by the coordinator at each rebind / restart.
static func create(game: MatchGame) -> MatchContext:
	var ctx := MatchContext.new()
	ctx.root = game
	ctx.canvas = game._canvas
	ctx.encounter = game._encounter
	ctx.session = game._session
	ctx.view = game._view
	ctx.grid = game._grid
	ctx.match_view = game._match_view
	ctx.player_portrait = game._player_portrait
	ctx.opponent_portrait = game._opponent_portrait
	ctx.round_label = game._round_label
	ctx.turn_label = game._turn_label
	ctx.actions = game._actions
	ctx.ruleset = game.ruleset
	ctx.config = game.config
	ctx.cell_size = MatchGame._CELL_SIZE
	ctx.input_mode = game.input_mode
	ctx.allow_diagonal = game.allow_diagonal
	ctx.set_status = game._set_status
	ctx.rules = MatchRulesEngine.new(ctx)
	ctx.popups = MatchPopups.new(ctx)
	ctx.abilities = MatchAbilityBar.new(ctx)
	ctx.readouts = MatchReadouts.new(ctx)
	ctx.resolver = MatchClearResolver.new(ctx)
	ctx.end_state = MatchEndState.new(ctx)
	ctx.turn_loop = MatchTurnLoop.new(ctx)
	return ctx

#endregion
