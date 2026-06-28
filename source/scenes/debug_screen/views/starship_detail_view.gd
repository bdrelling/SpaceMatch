class_name StarshipDetailView
extends DebugView
## Editor for one [StarshipBlueprint] — its name (editable) and the module grid it uses (summary for now).
## Assigning and arranging module grids (the interactive part) is the next step.

var _starship: StarshipBlueprint

static func create(starship: StarshipBlueprint) -> StarshipDetailView:
	var view := StarshipDetailView.new()
	view._starship = starship
	return view

func title() -> String:
	if _starship == null or _starship.name.is_empty():
		return "Starship"
	return _starship.name

func _build() -> void:
	if _starship == null:
		return
	var starship := _starship

	add_child(DebugRow.text("Name", starship.name,
		func(value: String) -> void: starship.name = value))

	var grid := starship.module_grid
	if grid != null:
		add_child(_line("Module grid: %d × %d, %d modules" % [grid.columns, grid.rows, grid.modules.size()]))
	else:
		add_child(_line("No module grid assigned."))

	add_child(_line("\nAssigning and arranging module grids is the next step."))

func _line(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return label
