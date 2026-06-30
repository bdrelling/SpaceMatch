class_name StarshipTuningView
extends DebugView
## Live tuning for the two starships fighting the running encounter — one card per starship. Edits the starship itself:
## its current hull, its hull stat (the max-HP cap), and its combat stats, written straight onto the live starship
## so the change shows on the board at once. The match fights on clones, so a fresh match starts fresh — edits
## don't persist. Reads the running game off [member DebugConfig.active_state]; shows a notice when no encounter
## is live (e.g. from the main menu).

# The stats that move combat, paired with their [StarshipStats] property and the tile whose colour tags them: the
# four colored stat tiles each boost the resource they bank, the damage tile boosts the hit it deals.
const _STATS: Array[Dictionary] = [
	{"label": "Power", "prop": "power", "kind": 0},
	{"label": "Speed", "prop": "speed", "kind": 1},
	{"label": "Sensors", "prop": "sensors", "kind": 2},
	{"label": "Defense", "prop": "defense", "kind": 3},
	{"label": "Weapons", "prop": "weapons", "kind": 6},
]

func title() -> String:
	return "Starships"

func _build() -> void:
	var state := DebugConfig.active_state
	var encounter: EncounterState = state.encounter if state != null else null
	if encounter == null:
		var notice := Label.new()
		notice.text = "No encounter running.\nOpen this from a match to tune the starships."
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
		add_child(notice)
		return

	_build_starship_card(encounter, encounter.player, "Your Starship")
	_build_starship_card(encounter, encounter.opponent, "Opponent")

# A card of live sliders for one combatant: its current hull (HP, the live stat), its hull stat (the max-HP cap)
# and its combat stats (both on the persistent starship's base stats). Each slider writes straight onto the live
# state and emits changed so the board repaints at once.
func _build_starship_card(encounter: EncounterState, combatant: Combatant, fallback: String) -> void:
	if combatant == null or combatant.starship == null:
		return
	var starship: StarshipState = combatant.starship
	var card_title: String = starship.name if not starship.name.is_empty() else fallback
	var card := DebugRuleCard.create(card_title, Color.WHITE)
	add_child(card)

	card.add_row(DebugRow.slider("HP", Color.WHITE, 0, 100, combatant.health(),
		func(value: float) -> void:
			combatant.set_health(int(value))
			encounter.emit_changed()))
	if starship.base_stats == null:
		return
	card.add_row(DebugRow.slider("Hull (max HP)", Color.WHITE, 1, 100, starship.base_stats.health,
		func(value: float) -> void:
			starship.base_stats.health = int(value)
			encounter.emit_changed()))
	for stat: Dictionary in _STATS:
		var prop: String = stat["prop"]
		var label: String = stat["label"]
		var kind: int = stat["kind"]
		var current: int = starship.base_stats.get(prop)
		card.add_row(DebugRow.slider(label, MatchTile.color_of(kind), 0, 30, current,
			func(value: float) -> void:
				starship.base_stats.set(prop, int(value))
				encounter.emit_changed()))
