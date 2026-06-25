class_name RulesView
extends DebugView
## The player-facing, read-only summary of the rules in force this match — each rule named, with a plain
## description, no controls. Opened from the match's "Rules" top-bar action; the editable twin is the Debug
## → Match Rules page. Reads the match's own [MatchRules] (passed to [method create]), so it reflects exactly
## this encounter rather than the shared debug config.

var _rules: MatchRules
## The acting ship's own rules (extra turn, module rules), layered onto the match's for display — the set
## actually in force on that ship's turn.
var _extra_rules: Array[Rule] = []

## Builds a read-only view of [param rules], plus any [param extra_rules] the acting ship contributes.
static func create(rules: MatchRules, extra_rules: Array[Rule] = []) -> RulesView:
	var view := RulesView.new()
	view._rules = rules
	view._extra_rules = extra_rules
	return view

func title() -> String:
	return "Rules"

func _build() -> void:
	if _rules == null:
		return

	var all_rules: Array[Rule] = []
	all_rules.append_array(_rules.ruleset.rules)
	all_rules.append_array(_extra_rules)
	for rule: Rule in all_rules:
		if rule == null or not rule.enabled:
			continue
		var card := DebugRuleCard.create(RulePresentation.display_name(rule), RulePresentation.accent_for(rule))
		add_child(card)
		card.add_row(_line(_summary(rule)))

	var scoring := DebugRuleCard.create("Scoring", Color.WHITE)
	add_child(scoring)
	var formula := (
		"Bigger matches pay off super-linearly (Fibonacci)."
		if _rules.scoring is FibonacciScoringFormula
		else "A match of N is worth N."
	)
	scoring.add_row(_line(formula))

# A plain-language sentence for what a rule does, for the player.
func _summary(rule: Rule) -> String:
	var kind := RulePresentation.kind_of(rule)
	var kind_name := MatchTile.NAMES[kind] if kind >= 0 and kind < MatchTile.NAMES.size() else ""
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
		_:
			return "Active this match."

func _line(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return label
