class_name DebugNavRow
extends Button
## A full-width button that drills into another view, used by [method DebugRow.nav]. Scene-backed by
## [code]nav_row.tscn[/code] so it renders in the editor; [method configure] sets its text and wires the
## press callback.

## Wires the button: [param label_text] with an optional right-hand [param detail] hint; [param on_press]
## fires on tap.
func configure(label_text: String, detail: String, on_press: Callable) -> void:
	text = label_text if detail.is_empty() else "%s    ·  %s" % [label_text, detail]
	pressed.connect(func() -> void: on_press.call())
