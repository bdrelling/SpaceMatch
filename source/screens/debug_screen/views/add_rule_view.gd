class_name AddRuleView
extends DebugView
## Placeholder for the rule catalog — the picker the Match Rules "+" opens to add a rule. A rule is a
## configurable instance of an effect (the same effect vocabulary as abilities), so this becomes a list of
## effects to drop in: single-slot ones (e.g. scoring) replace the current rule in their category, stackable
## ones append. Lands with the catalogs work; today it just explains the shape.


func title() -> String:
	return "Add Rule"


func _build() -> void:
	var note := Label.new()
	note.text = (
		"Rule catalog — coming with the catalogs work.\n\n"
		+ 'A rule is a configurable effect (e.g. "Combat tiles deal damage to all"). '
		+ "Picking one here adds it: single-slot categories (like scoring) replace the current rule; "
		+ "stackable categories append. Starship rules will take precedence over match rules."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	add_child(note)
