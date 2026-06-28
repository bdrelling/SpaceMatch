class_name SelectionRule
extends Resource
## How tiles are selected on a match board — one swappable "selection modifier" the encounter defaults to
## and any starship can override on its turn (Fluxx-style: the rules of play change with who's acting).
## Author a `.tres` per rule and carry it on a [SelectionDefaultRule] in the match ruleset (the board default)
## or on [member StarshipState.selection_override] (per-starship, which takes precedence on that starship's turn).
## [MatchMinigame] applies the active rule live as turns pass.

## The ways a player picks tiles. Maps to the engine's [enum MatchBoardView.InputMode] via [method input_mode].
enum Mode {
	SWAP,      ## Grab a tile and swap it with an adjacent neighbour (Bejeweled).
	SLIDE,     ## Grab a tile and slide it along one axis any distance; the run rotates (Puzzle & Dragons).
	TRACE,     ## Press a tile and trace through same-kind neighbours; release pops the whole traced run.
	TELEPORT,  ## Tap one tile, then another, and they trade places (within [member teleport_range]).
}

@export var mode: Mode = Mode.SWAP
## Count diagonals as adjacent everywhere the mode looks — line matches, swaps, and path steps.
@export var allow_diagonal: bool = false
## Shortest run that clears, and (for [constant Mode.TRACE]) the shortest poppable traced run.
@export var min_run: int = 3
## Revert a SWAP / SLIDE / TELEPORT move that makes no match. TRACE ignores it — a too-short run simply
## doesn't pop.
@export var match_required: bool = true
## [constant Mode.TELEPORT] only: largest king-move distance between the two picked tiles. Zero means the
## whole board is reachable.
@export var teleport_range: int = 0

## The engine input mode this rule drives.
func input_mode() -> MatchBoardView.InputMode:
	match mode:
		Mode.SLIDE:
			return MatchBoardView.InputMode.LINE_SHIFT
		Mode.TRACE:
			return MatchBoardView.InputMode.CONNECT
		Mode.TELEPORT:
			return MatchBoardView.InputMode.TELEPORT
		_:
			return MatchBoardView.InputMode.SWAP

## The [enum Mode] for an engine [param input_mode] — the inverse of [method input_mode], for building a
## rule from the legacy mode export.
static func mode_from_input(input: MatchBoardView.InputMode) -> Mode:
	match input:
		MatchBoardView.InputMode.LINE_SHIFT:
			return Mode.SLIDE
		MatchBoardView.InputMode.CONNECT:
			return Mode.TRACE
		MatchBoardView.InputMode.TELEPORT:
			return Mode.TELEPORT
		_:
			return Mode.SWAP

## A SelectionRule built in code — for defaults and the standalone board's fallback.
static func make(mode: Mode = Mode.SWAP, allow_diagonal: bool = false, min_run: int = 3, match_required: bool = true, teleport_range: int = 0) -> SelectionRule:
	var rule := SelectionRule.new()
	rule.mode = mode
	rule.allow_diagonal = allow_diagonal
	rule.min_run = min_run
	rule.match_required = match_required
	rule.teleport_range = teleport_range
	return rule
