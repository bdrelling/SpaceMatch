class_name DebugToggleRow
extends HBoxContainer
## A labelled on/off switch, used by [method DebugRow.toggle]. Scene-backed by [code]toggle_row.tscn[/code]
## so it renders in the editor; [method configure] seeds the switch and wires the change callback.

## Wires the row: [param label_text] beside a switch seeded to [param value]; [param on_change] receives the
## new state. Called off-tree right after instantiation, so nodes are reached by unique name rather than
## [code]@onready[/code].
func configure(label_text: String, value: bool, on_change: Callable) -> void:
	var label: Label = %Label
	label.text = label_text

	var switch: CheckButton = %Switch
	switch.button_pressed = value
	switch.toggled.connect(func(pressed: bool) -> void: on_change.call(pressed))
