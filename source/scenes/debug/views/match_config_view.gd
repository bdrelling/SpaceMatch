class_name MatchConfigView
extends DebugView
## The board page — the [MatchConfig] geometry (size, shortest run), edited on the shared
## [member DebugConfig.match_config]. Board shape is fixed once a board is laid out, so size and min run are
## editable only with no encounter running (they'd otherwise change nothing until a restart); during an
## encounter they show read-only. (Warp on/off is a rule — see Match Rules; whether a starship can warp is a
## warp-core module.)

func title() -> String:
	return "Board"

func _build() -> void:
	var config := DebugConfig.match_config
	var state := DebugConfig.active_state
	var in_encounter: bool = state != null and state.encounter != null

	var card := DebugRuleCard.create("Board", Color.WHITE)
	add_child(card)
	if in_encounter:
		# Shape is locked mid-encounter — show the values, don't pretend a slider here does anything.
		card.add_row(_readonly("Width", config.board_width))
		card.add_row(_readonly("Height", config.board_height))
		card.add_row(_readonly("Min run", config.min_run))
	else:
		card.add_row(DebugRow.slider("Width", Color.WHITE, 3, 12, config.board_width,
			func(value: float) -> void: config.board_width = int(value)))
		card.add_row(DebugRow.slider("Height", Color.WHITE, 3, 12, config.board_height,
			func(value: float) -> void: config.board_height = int(value)))
		card.add_row(DebugRow.slider("Min run", Color.WHITE, 3, 5, config.min_run,
			func(value: float) -> void: config.min_run = int(value)))

	if in_encounter:
		var note := Label.new()
		note.text = "Board size is fixed during an encounter. Start a fresh one to change it."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
		add_child(note)

func _readonly(label_text: String, value: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(360, 0)
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	row.add_child(label)
	var readout := Label.new()
	readout.text = str(value)
	readout.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	readout.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	row.add_child(readout)
	return row
