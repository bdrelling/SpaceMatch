class_name SelectionDefaultRule
extends Rule
## The board's default tile-selection (swap / slide / trace / teleport) as a composable rule: it carries the
## [SelectionRule] the board plays by when the acting ship names no [member StarshipState.selection_override].
## Drop it and selection falls back to the match's legacy mode export; a ship still overrides selection on its
## own turn. Holding the default in the ruleset is what lets a mode ship its own selection without a wrapper.

## The selection rule the board defaults to. Null leaves the board on its legacy mode export.
@export var selection: SelectionRule

func _init() -> void:
	rule_name = &"selection_default"
