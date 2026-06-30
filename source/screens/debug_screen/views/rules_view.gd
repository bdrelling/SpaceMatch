class_name RulesView
extends DebugView
## The player-facing, read-only summary of the rules in force this match — each rule named, with a plain
## description, no controls. Opened from the match's "Rules" top-bar action; the editable twin is the Debug
## → Match Rules page. Reads the match's own [Ruleset] (passed to [method create]), so it reflects exactly
## this encounter rather than the shared debug config.

var _ruleset: Ruleset
## The acting starship's own rules (extra turn, module rules), layered onto the match's for display — the set
## actually in force on that starship's turn.
var _extra_rules: Array[Rule] = []

## Builds a read-only view of [param ruleset], plus any [param extra_rules] the acting starship contributes.
static func create(ruleset: Ruleset, extra_rules: Array[Rule] = []) -> RulesView:
	var view := RulesView.new()
	view._ruleset = ruleset
	view._extra_rules = extra_rules
	return view

func title() -> String:
	return "Rules"

func _build() -> void:
	if _ruleset == null:
		return

	var all_rules: Array[Rule] = []
	all_rules.append_array(_ruleset.rules)
	all_rules.append_array(_extra_rules)
	for rule: Rule in all_rules:
		if rule == null or not rule.enabled:
			continue
		var card := DebugRuleCard.create(RulePresentation.display_name(rule), RulePresentation.accent_for(rule))
		add_child(card)
		card.add_row(_line(_summary(rule)))

# A plain-language sentence for what a rule does, for the player.
func _summary(rule: Rule) -> String:
	var kind := RulePresentation.kind_of(rule)
	var kind_name := MatchTile.name_of(kind) if kind >= 0 and kind < MatchTile.KIND_COUNT else ""
	match String(rule.rule_name):
		"resource_grant":
			return "Matching stat tiles banks their resource to whoever cleared them."
		"scrap_grant":
			return "Matching Scrap adds it to your wallet."
		"damage":
			return "Matching %s tiles damages the opponent." % kind_name
		"warp":
			return "Matching Warp charges the shared warp meter."
		"extra_turn":
			var extra := rule as ExtraTurnRule
			if extra != null and extra.min_match > 0:
				return "A match of %d or more grants another turn." % extra.min_match
			return "A combo grants another turn."
		"scoring":
			var scoring := rule as ScoringRule
			if scoring != null and scoring.formula is FibonacciScoringFormula:
				return "Bigger matches pay off super-linearly (Fibonacci)."
			return "A match of N is worth N."
		"board_fill":
			return "Fresh tiles refill from one edge of the board."
		"reload_split":
			return "A stalemate splits the board's tiles between both sides."
		"territory":
			return "Tiles you clear refill owned by your side."
		_:
			return "Active this match."

func _line(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return label
