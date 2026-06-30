class_name MatchRulesView
extends DebugView
## The match-tuning page. Each rule in the shared [DebugConfig.match_ruleset] is drawn as a named, dashed
## [DebugRuleCard] — title from its [member Rule.rule_name] (or the resource a spawn rule drops), accent from the
## resource it acts on, and a row per configurable field (introspected). Nested rulesets
## ([member Ruleset.rulesets], e.g. the Spawn set) show as a labelled group with their rules under it. Edits hit
## the shared rules, so they apply live on a running board. The header "+" opens the rule catalog.

# Base [Rule] fields shown as the card's on/off and title rather than generic config rows. combine_mode is
# rendered as its own Replace / Stack picker.
const _SKIP_PROPS: Array[String] = ["rule_name", "phase", "enabled", "combine_mode"]

var _ruleset: Ruleset

## Builds an editor for [param ruleset] (a mode from the [RuleCatalog]).
static func create(ruleset: Ruleset) -> MatchRulesView:
	var view := MatchRulesView.new()
	view._ruleset = ruleset
	return view

func title() -> String:
	return "Match Rules"

func action() -> Button:
	var button := Button.new()
	button.text = "+"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(64, 0)
	button.add_theme_font_size_override("font_size", 40)
	button.pressed.connect(func() -> void: _push(AddRuleView.new()))
	return button

func _build() -> void:
	if _ruleset == null:
		return
	_add_ruleset(_ruleset)

# Draws a ruleset: each nested child set as a labelled group with its rules under it (recursively), then this
# set's own rules as cards. Mirrors how [method Ruleset.flattened] folds the tree together.
func _add_ruleset(ruleset: Ruleset) -> void:
	for child: Ruleset in ruleset.rulesets:
		if child == null:
			continue
		add_child(_group_header(child))
		_add_ruleset(child)
	for rule: Rule in ruleset.rules:
		if rule == null:
			continue
		var card := DebugRuleCard.create(_rule_title(rule), RulePresentation.accent_for(rule))
		add_child(card)
		_add_rule_rows(card, rule)

# A heading for a nested ruleset group, from its [member Ruleset.ruleset_name].
func _group_header(ruleset: Ruleset) -> Label:
	var label := Label.new()
	var group_name := String(ruleset.ruleset_name)
	label.text = group_name.capitalize() if not group_name.is_empty() else "Rules"
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return label

# A card title: a spawn rule reads as the resource it drops; every other rule as its name.
func _rule_title(rule: Rule) -> String:
	if rule is SpawnResourceRule:
		var spawn := rule as SpawnResourceRule
		if spawn.resource != null:
			return MatchTile.name_of(spawn.resource.id)
	return RulePresentation.display_name(rule)

# Builds a card's rows: an on/off toggle, then a control per configurable field, read off the rule by type.
func _add_rule_rows(card: DebugRuleCard, rule: Rule) -> void:
	if rule is SpawnResourceRule:
		_add_spawn_resource_rows(card, rule as SpawnResourceRule)
		return

	card.add_row(DebugRow.toggle("Enabled", rule.enabled,
		func(value: bool) -> void: rule.enabled = value))

	for prop: Dictionary in rule.get_property_list():
		var usage: int = prop.usage
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var prop_name: String = prop.name
		if prop_name in _SKIP_PROPS:
			continue
		var r := rule
		var p := prop_name
		var label := p.capitalize()
		var prop_type: int = prop.type
		match prop_type:
			TYPE_INT:
				var current_int: int = r.get(p)
				card.add_row(DebugRow.slider(label, Color.WHITE, 0, 10, current_int,
					func(value: float) -> void: r.set(p, int(value))))
			TYPE_OBJECT:
				# A single-resource rule (scrap / damage / warp) — show which resource it acts on, read-only.
				if p == "resource":
					card.add_row(_resource_label(label, r.get(p)))
			TYPE_ARRAY:
				# A multi-resource rule (resource grant) — show the resources it banks, read-only.
				if p == "resources":
					card.add_row(_resources_label(label, r.get(p)))
			TYPE_BOOL:
				var current_bool: bool = r.get(p)
				card.add_row(DebugRow.toggle(label, current_bool,
					func(value: bool) -> void: r.set(p, value)))
			TYPE_FLOAT:
				var current_float: float = r.get(p)
				card.add_row(DebugRow.slider(label, Color.WHITE, 0, 10, current_float,
					func(value: float) -> void: r.set(p, value)))
			TYPE_PACKED_INT32_ARRAY:
				card.add_row(_kinds_label(label, r.get(p)))

	# How this rule merges with a same-key rule when a starship layers its own over the match's.
	card.add_row(_combine_mode_row(rule))

	# Scoring's formula is a resource, not a scalar field — surface it as a Linear / Fibonacci pick.
	if rule is ScoringRule:
		var scoring := rule as ScoringRule
		card.add_row(DebugRow.option("Match reward", ["Linear (N→N)", "Fibonacci"],
			1 if scoring.formula is FibonacciScoringFormula else 0,
			func(index: int) -> void:
				scoring.formula = FibonacciScoringFormula.new() if index == 1 else ScoringFormula.new()))

# A spawn rule's rows: on/off, its tile-tinted weight, and how it merges with a same-resource rule.
func _add_spawn_resource_rows(card: DebugRuleCard, rule: SpawnResourceRule) -> void:
	card.add_row(DebugRow.toggle("Enabled", rule.enabled,
		func(value: bool) -> void: rule.enabled = value))
	var color: Color = MatchTile.color_of(rule.resource.id) if rule.resource != null else Color.WHITE
	card.add_row(DebugRow.slider("Weight", color, 0, 50, rule.weight,
		func(value: float) -> void: rule.weight = int(value)))
	card.add_row(_combine_mode_row(rule))

# A Replace / Stack picker for a rule's [member Rule.combine_mode] (REPLACE = 0, STACK = 1).
func _combine_mode_row(rule: Rule) -> Control:
	return DebugRow.option("On collision", ["Replace", "Stack"], rule.combine_mode,
		func(index: int) -> void: rule.combine_mode = index)

# A read-only summary of a per-kind int array (e.g. capacity maximums) as resource names.
func _kinds_label(label: String, raw: Variant) -> Label:
	var names := PackedStringArray()
	if typeof(raw) == TYPE_PACKED_INT32_ARRAY:
		var kinds: PackedInt32Array = raw
		for k: int in kinds:
			if k >= 0:
				names.append(MatchTile.name_of(k))
	var node := Label.new()
	node.text = "%s: %s" % [label, ", ".join(names)]
	node.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return node

# A read-only summary of a single [StarshipResource] field (the resource a scrap / damage / warp rule acts on).
func _resource_label(label: String, raw: Variant) -> Label:
	var text := ""
	if raw is StarshipResource:
		var resource: StarshipResource = raw
		if resource.id >= 0:
			text = MatchTile.name_of(resource.id)
	var node := Label.new()
	node.text = "%s: %s" % [label, text]
	node.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return node

# A read-only summary of an [Array][[StarshipResource]] field (the resources the grant rule banks).
func _resources_label(label: String, raw: Variant) -> Label:
	var names := PackedStringArray()
	if raw is Array:
		var entries: Array = raw
		for entry: Variant in entries:
			if entry is StarshipResource:
				var resource: StarshipResource = entry
				if resource.id >= 0:
					names.append(MatchTile.name_of(resource.id))
	var node := Label.new()
	node.text = "%s: %s" % [label, ", ".join(names)]
	node.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return node
