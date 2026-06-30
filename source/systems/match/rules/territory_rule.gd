class_name TerritoryRule
extends Rule
## Marks a match as a shared-board territory fight: refilled tiles are tagged with the side that cleared them
## and outlined in that side's colour. A composable [Rule] — present in the active ruleset, the host tags and
## tints refills by owner; absent, tiles are ownerless and uncoloured, so ordinary modes are untouched. Pair
## it with per-ship [BoardFillRule]s so each side's clears refill from its own edge.
##
## The win condition (occupy the most board, steal the foe's mana, …) is deliberately left open: a concrete
## subclass overrides [method apply] at e.g. [constant MatchPhase.MOVE_RESOLVED] to scan the board's
## `state["owner"]` counts (the one seam every territory scoring reads) and score from there.

## Outline colour per side; the host reads these via [method color_for] when painting a tile.
@export var player_color: Color = Color(0.30, 0.62, 1.0)
@export var opponent_color: Color = Color(1.0, 0.34, 0.34)

func _init() -> void:
	rule_name = &"territory"

## The outline colour for [param owner] — a combatant's [member Entity.id] (0 = player, 1 = opponent),
## transparent for neutral/unowned (-1).
func color_for(owner: int) -> Color:
	match owner:
		0:
			return player_color
		1:
			return opponent_color
		_:
			return Color(0, 0, 0, 0)
