class_name StarshipTuningView
extends DebugView
## Live tuning for the two starships fighting the running encounter — one card per ship. Edits the ship itself:
## its current hull, its hull stat (the max-HP cap), and its combat stats, written straight onto the live ship
## so the change shows on the board at once. The match fights on clones, so a fresh match starts fresh — edits
## don't persist. Reads the running game off [member DebugConfig.active_state]; shows a notice when no encounter
## is live (e.g. from the main menu).

# The stats that move combat, paired with their [StarshipStats] property and the tile whose colour tags them: the
# four colored stat tiles each boost the resource they bank, the damage tile boosts the hit it deals.
const _STATS: Array[Dictionary] = [
	{"label": "Power", "prop": "power", "kind": 0},
	{"label": "Speed", "prop": "speed", "kind": 1},
	{"label": "Sensors", "prop": "sensors", "kind": 2},
	{"label": "Shields", "prop": "shields", "kind": 3},
	{"label": "Damage", "prop": "damage", "kind": 6},
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

	_build_ship_card(encounter, EncounterState.Combatant.PLAYER, "Your Starship")
	_build_ship_card(encounter, EncounterState.Combatant.OPPONENT, "Opponent")

# A card of live sliders for one fight ship: its current hull (HP), its hull stat (the max-HP cap), and its
# combat stats. Each slider writes straight onto the ship and emits changed so the board repaints at once.
func _build_ship_card(encounter: EncounterState, combatant: EncounterState.Combatant, fallback: String) -> void:
	var ship: StarshipState = encounter.ship_of(combatant)
	if ship == null:
		return
	var card_title: String = ship.name if not ship.name.is_empty() else fallback
	var card := DebugRuleCard.create(card_title, Color.WHITE)
	add_child(card)

	card.add_row(DebugRow.slider("HP", Color.WHITE, 0, 100, ship.health,
		func(value: float) -> void:
			ship.health = int(value)
			encounter.emit_changed()))
	if ship.stats == null:
		return
	card.add_row(DebugRow.slider("Hull (max HP)", Color.WHITE, 1, 100, ship.stats.health,
		func(value: float) -> void:
			ship.stats.health = int(value)
			encounter.emit_changed()))
	for stat: Dictionary in _STATS:
		var prop: String = stat["prop"]
		var label: String = stat["label"]
		var kind: int = stat["kind"]
		var current: int = ship.stats.get(prop)
		card.add_row(DebugRow.slider(label, MatchTile.color_of(kind), 0, 30, current,
			func(value: float) -> void:
				ship.stats.set(prop, int(value))
				encounter.emit_changed()))
