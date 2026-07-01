class_name AbilitiesView
extends DebugView
## The abilities page: every starship ability listed read-only — its name, what it does, and its cost. Reads the
## live player starship's abilities (its hull kit + modules), or a fresh default starship's kit when no game is
## live. The in-page editor was removed with the old effect model; a new one lands in a later pass.


func title() -> String:
	return "Abilities"


# The starship whose abilities this page shows: the live game's player starship, or a fresh default when none is live.
func _starship() -> StarshipState:
	if DebugConfig.active_state != null and DebugConfig.active_state.starship != null:
		return DebugConfig.active_state.starship
	return GameState.new().starship


func _build() -> void:
	var starship := _starship()
	var abilities: Array[Ability] = starship.abilities if starship != null else []
	if abilities.is_empty():
		add_child(_label("No abilities configured."))
		return
	for ability: Ability in abilities:
		if ability == null:
			continue
		add_child(_label("%s — %s (%s)" % [str(ability.name), ability.describe(), _cost_summary(ability)]))


# A short price for the row — "10 + 12" total tiles spent, or "free" when the ability has no costs.
func _cost_summary(ability: Ability) -> String:
	if ability.costs.is_empty():
		return "free"
	var parts: Array[String] = []
	for cost: ResourceCost in ability.costs:
		parts.append(str(cost.amount))
	return "cost %s" % " + ".join(parts)


# One read-only text row, styled like the rest of the debug list.
func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return label
