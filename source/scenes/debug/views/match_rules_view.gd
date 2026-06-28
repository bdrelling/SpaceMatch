class_name MatchRulesView
extends DebugView
## The match-tuning page. Each rule in the shared [DebugConfig.match_rules] ruleset is drawn as a named,
## dashed [DebugRuleCard] — title from its [member Rule.rule_name], accent from the resource it acts on, and
## a row per configurable field (introspected). Resource-bound rules read in their tile's colour; independent
## ones (e.g. extra turns) stand on their own. Spawn weights and scoring follow as match-level config cards.
## Edits hit the shared rules, so they apply live on a running board. The header "+" opens the rule catalog.

# Base [Rule] fields shown as the card's on/off and title rather than generic config rows.
const _SKIP_PROPS: Array[String] = ["rule_name", "phase", "enabled"]

var _rules: MatchRules

## Builds an editor for [param rules] (a ruleset from the [RuleCatalog]).
static func create(rules: MatchRules) -> MatchRulesView:
	var view := MatchRulesView.new()
	view._rules = rules
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
	var rules := _rules
	if rules == null:
		return

	for rule: Rule in rules.ruleset.rules:
		if rule == null:
			continue
		var card := DebugRuleCard.create(RulePresentation.display_name(rule), RulePresentation.accent_for(rule))
		add_child(card)
		_add_rule_rows(card, rule)

	# Scoring is a single-slot "interaction" — one per scope, starship over match. Linear vs super-linear.
	var scoring := DebugRuleCard.create("Scoring", Color.WHITE)
	add_child(scoring)
	scoring.add_row(DebugRow.option("Match reward", ["Linear (N→N)", "Fibonacci"],
		1 if rules.scoring is FibonacciScoringFormula else 0,
		func(index: int) -> void:
			rules.scoring = FibonacciScoringFormula.new() if index == 1 else ScoringFormula.new()))

# Builds a card's rows: an on/off toggle, then a control per configurable field, read off the rule by type.
func _add_rule_rows(card: DebugRuleCard, rule: Rule) -> void:
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
				if p == "kind":
					var current_kind: int = r.get(p)
					card.add_row(DebugRow.option(label, MatchTile.NAMES, current_kind,
						func(index: int) -> void: r.set(p, index)))
				elif p == "spawn_weight":
					# The rule's own spawn weight — tinted by the tile it spawns, ranged like the old pool card.
					var weight: int = r.get(p)
					card.add_row(DebugRow.slider("Spawn weight", _rule_tile_color(r), 0, 50, weight,
						func(value: float) -> void: r.set(p, int(value))))
				else:
					var current_int: int = r.get(p)
					card.add_row(DebugRow.slider(label, Color.WHITE, 0, 10, current_int,
						func(value: float) -> void: r.set(p, int(value))))
			TYPE_BOOL:
				var current_bool: bool = r.get(p)
				card.add_row(DebugRow.toggle(label, current_bool,
					func(value: bool) -> void: r.set(p, value)))
			TYPE_FLOAT:
				var current_float: float = r.get(p)
				card.add_row(DebugRow.slider(label, Color.WHITE, 0, 10, current_float,
					func(value: float) -> void: r.set(p, value)))
			TYPE_PACKED_INT32_ARRAY:
				if p == "spawn_weights":
					_add_spawn_weight_rows(card, r)
				else:
					card.add_row(_kinds_label(label, r.get(p)))

# A read-only summary of a kinds array as resource names (multi-kind editing comes with the catalog work).
func _kinds_label(label: String, raw: Variant) -> Label:
	var names := PackedStringArray()
	if typeof(raw) == TYPE_PACKED_INT32_ARRAY:
		var kinds: PackedInt32Array = raw
		for k: int in kinds:
			if k >= 0 and k < MatchTile.NAMES.size():
				names.append(MatchTile.NAMES[k])
	var node := Label.new()
	node.text = "%s: %s" % [label, ", ".join(names)]
	node.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return node

# A slider per kind a multi-kind rule (the resource grant) spawns, tinted by that tile — the per-stat-tile
# weights that used to live on the match-level card now sit on the rule that owns those tiles.
func _add_spawn_weight_rows(card: DebugRuleCard, rule: Rule) -> void:
	var kinds: PackedInt32Array = rule.get("kinds")
	var weights: PackedInt32Array = rule.get("spawn_weights")
	for i: int in weights.size():
		var index := i
		var kind: int = kinds[index] if index < kinds.size() else index
		var current: int = weights[index]
		card.add_row(DebugRow.slider(MatchTile.NAMES[kind], MatchTile.color_of(kind), 0, 50, current,
			func(value: float) -> void:
				var array: PackedInt32Array = rule.get("spawn_weights")
				array[index] = int(value)
				rule.set("spawn_weights", array)))

# The colour of the tile a single-kind rule spawns (scrap / damage / warp), for tinting its weight slider.
func _rule_tile_color(rule: Rule) -> Color:
	var raw: Variant = rule.get("kind")
	if typeof(raw) == TYPE_INT:
		var kind: int = raw
		return MatchTile.color_of(kind)
	return Color.WHITE
