class_name ModuleGridDetailView
extends DebugView
## Read-only summary of one [ModuleGridBlueprint] — its dimensions, usable-cell count, and the modules
## stamped into it. Arranging modules on the grid (the interactive part) is the next step.

var _grid: ModuleGridBlueprint

static func create(grid: ModuleGridBlueprint) -> ModuleGridDetailView:
	var view := ModuleGridDetailView.new()
	view._grid = grid
	return view

func title() -> String:
	return "Module Grid"

func _build() -> void:
	if _grid == null:
		return

	var usable := _grid.cells.size() if not _grid.cells.is_empty() else _grid.columns * _grid.rows
	add_child(_line("%d × %d  ·  %d usable cells" % [_grid.columns, _grid.rows, usable]))

	add_child(_heading("Modules placed"))
	if _grid.modules.is_empty():
		add_child(_line("None."))
	else:
		for placement: ModulePlacement in _grid.modules:
			if placement == null or placement.module == null:
				continue
			add_child(_line("• %s  @ (%d, %d)  ↻%d" % [
				placement.module.name, placement.origin.x, placement.origin.y, placement.rotation,
			]))

	add_child(_line("\nArranging modules on the grid is the next step."))

func _heading(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 36)
	return label

func _line(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	return label
