class_name ExtraTurnRule
extends Rule
## Keeps the board with the mover for another action when their move cleared a big enough match — a straight
## run (or bent/path match, by [method MatchGame._largest_match]) of at least [member min_match] tiles.
## The migrated form of the old [code]extra_turn_min_match[/code] knob: now a swappable [Rule] on the
## [MOVE_RESOLVED][MatchPhase] phase, so an encounter (or a player) can drop it, retune it, or stack a variant.

## A match of at least this many tiles grants another turn. Zero disables the rule.
@export var min_match: int = 0

func _init() -> void:
	rule_name = &"extra_turn"
	phase = MatchPhase.MOVE_RESOLVED

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null:
		return
	if min_match > 0 and match_context.max_run >= min_match:
		match_context.go_again = true
		match_context.go_again_reason = "Match-%d" % match_context.max_run
