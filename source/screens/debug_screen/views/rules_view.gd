class_name RulesView
extends DebugView
## The player-facing, read-only summary of the rules in force this match — each rule named, with a plain
## description, no controls. Opened from the match's "Rules" top-bar action; the editable twin is the Debug
## → Match Rules page. Reads the match's own [Ruleset] (passed to [method create]), so it reflects exactly
## this encounter rather than the shared debug config.

const _SUMMARIES := {
	"resource_grant": "Matching stat tiles banks their resource to whoever cleared them.",
	"scrap_grant": "Matching Scrap adds it to your wallet.",
	"warp": "Matching Warp charges the shared warp meter.",
	"board_fill": "Fresh tiles refill from one edge of the board.",
	"reload_split": "A stalemate splits the board's tiles between both sides.",
	"territory": "Tiles you clear refill owned by your side.",
}

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
	if rule is SpawnResourceRule:
		var spawn := rule as SpawnResourceRule
		var spawn_name: String = MatchTile.name_of(spawn.resource.id) if spawn.resource != null else "These"
		return "%s tiles drop onto the board." % spawn_name
	var kind := RulePresentation.kind_of(rule)
	var kind_name := MatchTile.name_of(kind) if kind >= 0 else ""
	var rule_name := String(rule.rule_name)
	var text := str(_SUMMARIES.get(rule_name, "Active this match."))
	match rule_name:
		"damage":
			text = "Matching %s tiles damages the opponent." % kind_name
		"extra_turn":
			var extra := rule as ExtraTurnRule
			if extra != null and extra.min_match > 0:
				text = "A match of %d or more grants another turn." % extra.min_match
			else:
				text = "A combo grants another turn."
		"scoring":
			var scoring := rule as ScoringRule
			if scoring != null and scoring.formula is FibonacciScoringFormula:
				text = "Bigger matches pay off super-linearly (Fibonacci)."
			else:
				text = "A match of N is worth N."
	return text


func _line(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return label
