class_name AbilityDetailView
extends DebugView
## One ability's editor — its name plus its lists of costs ([AbilityCost]) and effects ([AbilityEffect]),
## each addable and removable. Mutates the [MatchAbility] in place, so the changes are shared with wherever
## the ability is used. Structural edits (add/remove/retype) call [method rebuild] to redraw the page.
## Pushed from [AbilitiesView].

# Effect type labels for the dropdown, index-aligned with [method _effect_for_index] / [method _index_for_effect].
const _EFFECT_LABELS: Array[String] = ["Damage", "Shield", "Dodge", "Drain", "Damage buff", "Disable"]

var _ability: MatchAbility

## Builds an editor for [param ability].
static func create(ability: MatchAbility) -> AbilityDetailView:
	var view := AbilityDetailView.new()
	view._ability = ability
	return view

func title() -> String:
	return _ability.ability_name if _ability != null else "Ability"

func _build() -> void:
	if _ability == null:
		return
	var ability := _ability

	add_child(DebugRow.text("Name", ability.ability_name,
		func(value: String) -> void: ability.ability_name = value))

	add_child(_heading("Costs"))
	for index: int in ability.costs.size():
		_build_cost(ability.costs[index], index)
	add_child(DebugRow.nav("+ Add cost", "", func() -> void:
		ability.costs.append(AbilityCost.make(Catalogs.ability_resources.for_tile(0), 5))
		rebuild()))

	add_child(_heading("Effects"))
	for index: int in ability.effects.size():
		_build_effect(ability.effects[index], index)
	add_child(DebugRow.nav("+ Add effect", "", func() -> void:
		ability.effects.append(AttackEffect.new())
		rebuild()))

# One cost: the tile it spends, the amount, and a remove row.
func _build_cost(cost: AbilityCost, index: int) -> void:
	var current_kind: int = cost.resource.id if cost.resource != null else 0
	add_child(DebugRow.option("Cost %d tile" % (index + 1), MatchTile.names(), current_kind,
		func(picked: int) -> void: cost.resource = Catalogs.ability_resources.for_tile(picked)))
	add_child(DebugRow.slider("Amount", MatchTile.color_of(current_kind), 0, 30, cost.amount,
		func(value: float) -> void: cost.amount = int(value)))
	add_child(DebugRow.nav("Remove cost %d" % (index + 1), "", func() -> void:
		_ability.costs.erase(cost)
		rebuild()))

# One effect: its type, its single parameter (if it has one — a dodge has none), and a remove row. Switching
# the type swaps the effect instance for a fresh one of the chosen subclass, then redraws.
func _build_effect(effect: AbilityEffect, index: int) -> void:
	add_child(DebugRow.option("Effect %d" % (index + 1), _EFFECT_LABELS, _index_for_effect(effect),
		func(picked: int) -> void:
			_ability.effects[index] = _effect_for_index(picked)
			rebuild()))
	var param := _effect_param(effect)
	if not param.is_empty():
		var property: String = str(param[0])
		var label: String = str(param[1])
		var maximum: int = param[2]
		var current: float = effect.get(property)
		add_child(DebugRow.slider("  %s" % label, Color.WHITE, 0, maximum, current,
			func(value: float) -> void: effect.set(property, int(value))))
	add_child(DebugRow.nav("Remove effect %d" % (index + 1), "", func() -> void:
		_ability.effects.erase(effect)
		rebuild()))

# A bold section divider between the name, the costs, and the effects.
func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	label.add_theme_color_override("font_color", Color(0.70, 0.75, 0.88))
	return label

# The dropdown index for [param effect]'s type.
func _index_for_effect(effect: AbilityEffect) -> int:
	if effect is ShieldEffect:
		return 1
	if effect is DodgeEffect:
		return 2
	if effect is DrainEffect:
		return 3
	if effect is DamageBuffEffect:
		return 4
	if effect is DisableEffect:
		return 5
	return 0

# A fresh effect of the type at dropdown [param index].
func _effect_for_index(index: int) -> AbilityEffect:
	var effect: AbilityEffect = AttackEffect.new()
	match index:
		1:
			effect = ShieldEffect.new()
		2:
			effect = DodgeEffect.new()
		3:
			effect = DrainEffect.new()
		4:
			effect = DamageBuffEffect.new()
		5:
			effect = DisableEffect.new()
	return effect

# The editable parameter for [param effect] as [property, label, max], or [] for an effect with no amount
# (a dodge) — the case the flexible model exists to handle.
func _effect_param(effect: AbilityEffect) -> Array:
	if effect is DodgeEffect:
		return []
	if effect is DisableEffect:
		return ["turns", "Turns", 10]
	if effect is DamageBuffEffect:
		return ["amount", "Damage bonus", 10]
	return ["amount", "Amount", 30]
