class_name MatchBlueprint
extends GridSessionBlueprint
## Match-3 rules for the match minigame. One of three input modes drives the
## board — swap a neighbour, slide a whole run, or trace a connected path — and a
## single [member allow_diagonal] toggle fans out to every adjacency the chosen
## mode cares about (matches, swaps, connect steps). Call [method build] after
## changing any setting and before [code]GridSession.create[/code].

const _BOARD_WIDTH: int = 8
const _BOARD_HEIGHT: int = 8
const _MIN_RUN: int = 3

## Which verb the player uses; mirrored onto the [[MatchBoardView]].
@export var input_mode: MatchBoardView.InputMode = MatchBoardView.InputMode.SWAP
## Count diagonals as adjacent everywhere the mode looks — line matches, swaps,
## and connect-path steps alike. The single adjacency knob.
@export var allow_diagonal: bool = false
## Revert a move that completes no match (swap / line-shift). Connect ignores it
## — a too-short path simply doesn't pop.
@export var match_required: bool = true

func _init() -> void:
	width = _BOARD_WIDTH
	height = _BOARD_HEIGHT
	build()

## (Re)builds interactions and passives from the current settings.
func build() -> void:
	match input_mode:
		MatchBoardView.InputMode.CONNECT:
			_build_connect()
		MatchBoardView.InputMode.LINE_SHIFT:
			_build_line_shift()
		_:
			_build_swap()

func _build_swap() -> void:
	var swap := SwapInteraction.new()
	swap.resource_name = "swap"
	swap.allow_diagonal = allow_diagonal
	swap.revert_without_match = match_required
	swap.match_condition = _line_condition()
	_set_rules([swap], _clear_and_gravity())

func _build_line_shift() -> void:
	var shift := LineShiftInteraction.new()
	shift.resource_name = "line_shift"
	shift.revert_without_match = match_required
	shift.match_condition = _line_condition()
	_set_rules([shift], _clear_and_gravity())

func _build_connect() -> void:
	var connect := ConnectClearInteraction.new()
	connect.resource_name = "connect"
	connect.min_run_length = _MIN_RUN
	connect.allow_diagonal = allow_diagonal
	var gravity_only: Array[GridPassive] = [GravityPassive.new()]
	_set_rules([connect], gravity_only)

func _line_condition() -> MatchLineCondition:
	var condition := MatchLineCondition.new()
	condition.min_run_length = _MIN_RUN
	condition.diagonal = allow_diagonal
	return condition

func _clear_and_gravity() -> Array[GridPassive]:
	var clearer := MatchClearPassive.new(_line_condition())
	var passives: Array[GridPassive] = [clearer, GravityPassive.new()]
	return passives

func _set_rules(verbs: Array, passives: Array[GridPassive]) -> void:
	var typed: Array[GridInteraction] = []
	for verb: GridInteraction in verbs:
		typed.append(verb)
	interactions = typed
	passive_rules = passives
