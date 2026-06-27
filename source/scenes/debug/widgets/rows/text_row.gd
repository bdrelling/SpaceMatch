class_name DebugTextRow
extends HBoxContainer
## A labelled text field, used by [method DebugRow.text]. Scene-backed by [code]text_row.tscn[/code] so it
## renders in the editor; [method configure] seeds the field and wires the change callback.

## Wires the row: [param label_text] beside a field seeded to [param value]; [param on_change] receives the
## edited text on every keystroke. Called off-tree right after instantiation, so nodes are reached by unique
## name rather than [code]@onready[/code].
func configure(label_text: String, value: String, on_change: Callable) -> void:
	var label: Label = %Label
	label.text = label_text

	var field: LineEdit = %Field
	field.text = value
	field.text_changed.connect(func(new_text: String) -> void: on_change.call(new_text))
