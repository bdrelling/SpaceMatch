class_name BoardFillRule
extends Rule
## Which edge the board refills from after a clear — the direction settled tiles fall and fresh tiles stream
## in. A composable [Rule]: drop one in a match [Ruleset] to set the board's fill, or in a starship's ruleset
## (sharing this rule's [member Rule.rule_name]) to override it on that ship's turn, so each side can fill from
## its own edge. The host reads the active rule each turn and retunes the engine's [GravityPassive] — see
## MatchGame._sync_board_rules — the same out-of-band read [method Ruleset.aggregate] does for spawn
## weights. Absent entirely, the board falls top-down as classic match-3 does.

## The edge fresh tiles fall from.
enum Direction {
	TOP,     ## Tiles fall downward, refilling from the top (the classic match-3 default).
	BOTTOM,  ## Tiles rise, refilling from the bottom.
	LEFT,    ## Tiles slide right, refilling from the left.
	RIGHT,   ## Tiles slide left, refilling from the right.
}

@export var direction: Direction = Direction.TOP

func _init() -> void:
	# Shared name so a ship/module fill rule replaces the match's by [method Ruleset.remove_named] on compose.
	rule_name = &"board_fill"

## The gravity step vector the engine's [GravityPassive] settles along: objects move this way until they pile
## up, opening the empties on the opposite (entry) edge fresh tiles stream in from.
func direction_vector() -> Vector2i:
	match direction:
		Direction.BOTTOM:
			return Vector2i(0, -1)
		Direction.LEFT:
			return Vector2i(1, 0)
		Direction.RIGHT:
			return Vector2i(-1, 0)
		_:
			return Vector2i(0, 1)

## A BoardFillRule built in code — for defaults and tests.
static func make(fill_direction: Direction = Direction.TOP) -> BoardFillRule:
	var rule := BoardFillRule.new()
	rule.direction = fill_direction
	return rule
