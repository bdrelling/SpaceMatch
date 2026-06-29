class_name AbilitiesView
extends DebugView
## The abilities page: every starship ability as a row that drills into its editor ([AbilityDetailView]). Reads
## the live player starship's abilities (its hull kit + modules); edits in a detail page mutate the ability in
## place, so a running board uses the new values the next time the ability is used. With no live game it
## previews a fresh default starship's kit.

func title() -> String:
	return "Abilities"

# The starship whose abilities this page edits: the live game's player starship, or a fresh default when none is live.
func _starship() -> StarshipState:
	if DebugConfig.active_state != null and DebugConfig.active_state.starship != null:
		return DebugConfig.active_state.starship
	return GameState.new().starship

func _build() -> void:
	var starship := _starship()
	var abilities: Array[MatchAbility] = starship.abilities if starship != null else []
	if abilities.is_empty():
		var empty := Label.new()
		empty.text = "No abilities configured."
		empty.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
		add_child(empty)
		return
	for index: int in abilities.size():
		var ability := abilities[index]
		if ability == null:
			continue
		add_child(DebugRow.nav(ability.ability_name, _cost_summary(ability),
			func() -> void: _push(AbilityDetailView.create(ability))))

# A short price for the list subtitle — "10 + 12" total tiles spent, or "free" when the ability has no costs.
func _cost_summary(ability: MatchAbility) -> String:
	if ability.costs.is_empty():
		return "free"
	var parts: Array[String] = []
	for cost: AbilityCost in ability.costs:
		parts.append(str(cost.amount))
	return "cost %s" % " + ".join(parts)
