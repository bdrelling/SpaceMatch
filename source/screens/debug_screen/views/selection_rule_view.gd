class_name SelectionRuleView
extends DebugView
## The selection-rule editor — how tiles get picked on the board (swap / slide / trace / teleport) plus the
## adjacency, run-length and teleport-range knobs that turn one match engine into a different game. Edits the
## active ruleset's [SelectionDefaultRule]; each change assigns a fresh [SelectionRule] so the
## board re-points to it on the next turn (see [member MatchGame] — its per-turn re-sync only fires when
## the active rule's reference changes). A starship's [member StarshipState.selection_override] still wins on
## that starship's turn.

# Index-aligned with [enum SelectionRule.Mode] (SWAP, SLIDE, TRACE, TELEPORT).
const _MODE_LABELS: Array[String] = ["Swap", "Slide", "Trace", "Teleport"]

# The rule the page edits; a fresh copy is pushed to default_selection on every change (see [method _apply]).
var _selection: SelectionRule

func title() -> String:
	return "Selection"

func _build() -> void:
	var ruleset := DebugConfig.match_ruleset
	if ruleset == null:
		return
	if _selection == null:
		var rule := _default_rule(ruleset)
		_selection = rule.selection.duplicate() if rule != null and rule.selection != null else SelectionRule.make()

	# Mode swaps which interaction the board enables; rebuild so the teleport-range row tracks the choice.
	add_child(DebugRow.option("Mode", _MODE_LABELS, _selection.mode,
		func(index: int) -> void:
			_selection.mode = index
			_apply()
			rebuild()))

	add_child(DebugRow.toggle("Diagonals", _selection.allow_diagonal,
		func(value: bool) -> void:
			_selection.allow_diagonal = value
			_apply()))

	add_child(DebugRow.slider("Min run", Color.WHITE, 2, 6, _selection.min_run,
		func(value: float) -> void:
			_selection.min_run = int(value)
			_apply()))

	add_child(DebugRow.toggle("Revert non-matches", _selection.match_required,
		func(value: bool) -> void:
			_selection.match_required = value
			_apply()))

	if _selection.mode == SelectionRule.Mode.TELEPORT:
		add_child(DebugRow.slider("Teleport range (0 = any)", Color.WHITE, 0, 8, _selection.teleport_range,
			func(value: float) -> void:
				_selection.teleport_range = int(value)
				_apply()))

# Push a fresh copy onto the active rules: the board's per-turn re-sync only re-points when the active rule's
# reference changes, so an in-place edit to the live rule wouldn't take — a new instance always does.
func _apply() -> void:
	var ruleset := DebugConfig.match_ruleset
	if ruleset == null:
		return
	var rule := _default_rule(ruleset, true)
	if rule != null:
		rule.selection = _selection.duplicate()

# The default-selection rule in [param ruleset], creating and adding one when [param create] and none exists —
# so the debug editor can set a board default even on a mode authored without one.
func _default_rule(ruleset: Ruleset, create: bool = false) -> SelectionDefaultRule:
	for rule: Rule in ruleset.rules:
		if rule is SelectionDefaultRule:
			return rule as SelectionDefaultRule
	if create:
		var made := SelectionDefaultRule.new()
		ruleset.add(made)
		return made
	return null
