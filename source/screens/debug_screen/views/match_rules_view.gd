class_name MatchRulesView
extends DebugView
## The match-tuning page. Each rule in the shared [DebugConfig.match_ruleset] is drawn as a named,
## dashed [DebugRuleCard] — title from its [member Rule.rule_name], accent from the resource it acts on, and
## a row per configurable field (introspected). Resource-bound rules read in their tile's colour; independent
## ones (e.g. extra turns) stand on their own. Spawn weights and scoring follow as match-level config cards.
## Edits hit the shared rules, so they apply live on a running board. The header "+" opens the rule catalog.

# Base [Rule] fields shown as the card's on/off and title rather than generic config rows.
const _SKIP_PROPS: Array[String] = ["rule_name", "phase", "enabled"]

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

	for rule: Rule in _ruleset.rules:
		if rule == null:
			continue
		var card := DebugRuleCard.create(RulePresentation.display_name(rule), RulePresentation.accent_for(rule))
		add_child(card)
		_add_rule_rows(card, rule)

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
				if p == "spawn_weight":
					# The rule's own spawn weight — tinted by the tile it spawns, ranged like the old pool card.
					var weight: int = r.get(p)
					card.add_row(DebugRow.slider("Spawn weight", _rule_tile_color(r), 0, 50, weight,
						func(value: float) -> void: r.set(p, int(value))))
				else:
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
				if p == "spawn_weights":
					_add_spawn_weight_rows(card, r)
				else:
					card.add_row(_kinds_label(label, r.get(p)))

	# Scoring's formula is a resource, not a scalar field — surface it as a Linear / Fibonacci pick.
	if rule is ScoringRule:
		var scoring := rule as ScoringRule
		card.add_row(DebugRow.option("Match reward", ["Linear (N→N)", "Fibonacci"],
			1 if scoring.formula is FibonacciScoringFormula else 0,
			func(index: int) -> void:
				scoring.formula = FibonacciScoringFormula.new() if index == 1 else ScoringFormula.new()))

# A read-only summary of a per-kind int array (e.g. capacity maximums) as resource names.
func _kinds_label(label: String, raw: Variant) -> Label:
	var names := PackedStringArray()
	if typeof(raw) == TYPE_PACKED_INT32_ARRAY:
		var kinds: PackedInt32Array = raw
		for k: int in kinds:
			if k >= 0 and k < MatchTile.KIND_COUNT:
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
		if resource.tile_kind >= 0 and resource.tile_kind < MatchTile.KIND_COUNT:
			text = MatchTile.name_of(resource.tile_kind)
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
				if resource.tile_kind >= 0 and resource.tile_kind < MatchTile.KIND_COUNT:
					names.append(MatchTile.name_of(resource.tile_kind))
	var node := Label.new()
	node.text = "%s: %s" % [label, ", ".join(names)]
	node.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return node

# A slider per resource a multi-resource rule (the resource grant) spawns, tinted by that tile — the per-stat-
# tile weights that used to live on the match-level card now sit on the rule that owns those tiles.
func _add_spawn_weight_rows(card: DebugRuleCard, rule: Rule) -> void:
	var resources: Array = rule.get("resources")
	var weights: PackedInt32Array = rule.get("spawn_weights")
	for i: int in weights.size():
		var index := i
		var kind := index
		if index < resources.size() and resources[index] is StarshipResource:
			var resource: StarshipResource = resources[index]
			kind = resource.tile_kind
		var current: int = weights[index]
		card.add_row(DebugRow.slider(MatchTile.name_of(kind), MatchTile.color_of(kind), 0, 50, current,
			func(value: float) -> void:
				var array: PackedInt32Array = rule.get("spawn_weights")
				array[index] = int(value)
				rule.set("spawn_weights", array)))

# The colour of the tile a single-resource rule spawns (scrap / damage / warp), for tinting its weight slider.
func _rule_tile_color(rule: Rule) -> Color:
	var raw: Variant = rule.get("resource")
	if raw is StarshipResource:
		var resource: StarshipResource = raw
		if resource.tile_kind >= 0 and resource.tile_kind < MatchTile.KIND_COUNT:
			return MatchTile.color_of(resource.tile_kind)
	return Color.WHITE
