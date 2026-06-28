class_name MatchBlueprint
extends GridSessionBlueprint
## Match-3 rules for the match minigame. Builds every selection verb the board can use — swap a
## neighbour, slide a whole run, trace a connected path, or teleport two tiles — into one session, so the
## host can switch between them live by toggling which is enabled (see [MatchMinigame] / [SelectionRule]).
## The line-clear cascade and gravity ride alongside; [member input_mode] / [member allow_diagonal] seed
## the initial selection and adjacency. Call [method build] after changing any setting and before
## [code]GridSession.create[/code].

## Board dimensions and the shortest poppable run. The host seeds these from its [MatchConfig] before calling
## [method build]; left at the defaults the blueprint stands alone (e.g. running match.tscn directly).
@export var board_width: int = 8
@export var board_height: int = 8
@export var min_run: int = 3

## The verb the board starts on; the host re-points it live per turn via [SelectionRule].
@export var input_mode: MatchBoardView.InputMode = MatchBoardView.InputMode.SWAP
## Count diagonals as adjacent everywhere the mode looks — line matches, swaps,
## and connect-path steps alike. The single adjacency knob.
@export var allow_diagonal: bool = false
## Revert a move that completes no match (swap / line-shift / teleport). Connect ignores it
## — a too-short path simply doesn't pop.
@export var match_required: bool = true

func _init() -> void:
	build()

## (Re)builds every selection interaction and the clear/gravity passives. All verbs are created enabled;
## the host enables exactly the active one per turn (see [method MatchMinigame._apply_selection]). Picks up
## the current [member board_width] / [member board_height] / [member min_run], so a host that changed them
## need only call this again.
func build() -> void:
	width = board_width
	height = board_height

	var swap := SwapInteraction.new()
	swap.resource_name = "swap"
	swap.allow_diagonal = allow_diagonal
	swap.revert_without_match = match_required
	swap.match_condition = _line_condition()

	var shift := LineShiftInteraction.new()
	shift.resource_name = "line_shift"
	shift.revert_without_match = match_required
	shift.match_condition = _line_condition()

	var connect := ConnectClearInteraction.new()
	connect.resource_name = "connect"
	connect.min_run_length = min_run
	connect.allow_diagonal = allow_diagonal

	var teleport := TeleportInteraction.new()
	teleport.resource_name = "teleport"
	teleport.revert_without_match = match_required
	teleport.match_condition = _line_condition()

	_set_rules([swap, shift, connect, teleport], _clear_and_gravity())

func _line_condition() -> MatchLineCondition:
	var condition := MatchLineCondition.new()
	condition.min_run_length = min_run
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
