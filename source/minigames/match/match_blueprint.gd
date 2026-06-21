class_name MatchBlueprint
extends GridSessionBlueprint
## Match-3 rules for the match minigame: swap a cell toward a neighbour to line up three-or-more
## matching tiles, which clear and let the column refill.

const _BOARD_WIDTH: int = 8
const _BOARD_HEIGHT: int = 8
const _MIN_RUN: int = 3

func _init() -> void:
	width = _BOARD_WIDTH
	height = _BOARD_HEIGHT

	var swap_condition := MatchLineCondition.new()
	swap_condition.min_run_length = _MIN_RUN
	var swap := SwapInteraction.new()
	swap.resource_name = "swap"
	swap.match_condition = swap_condition
	var typed_interactions: Array[GridInteraction] = [swap]
	interactions = typed_interactions

	var clear_condition := MatchLineCondition.new()
	clear_condition.min_run_length = _MIN_RUN
	var clearer := MatchClearPassive.new(clear_condition)
	var typed_passives: Array[GridPassive] = [clearer, GravityPassive.new()]
	passive_rules = typed_passives
