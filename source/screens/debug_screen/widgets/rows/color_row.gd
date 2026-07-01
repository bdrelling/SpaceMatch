class_name DebugColorRow
extends HBoxContainer
## A labelled colour picker, used by [method DebugRow.color]. Scene-backed by [code]color_row.tscn[/code] so it
## renders in the editor; [method configure] seeds the swatch and wires the change callback.

## Wires the row: [param label_text] beside a colour swatch seeded to [param value]; [param on_change] receives
## the chosen [Color]. Called off-tree right after instantiation, so nodes are reached by unique name.
func configure(label_text: String, value: Color, on_change: Callable) -> void:
	var label: Label = %Label
	label.text = label_text
	var picker: ColorPickerButton = %Picker
	picker.color = value
	picker.color_changed.connect(func(color: Color) -> void: on_change.call(color))
