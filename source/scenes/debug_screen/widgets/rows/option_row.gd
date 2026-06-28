class_name DebugOptionRow
extends HBoxContainer
## A labelled dropdown, used by [method DebugRow.option]. Scene-backed by [code]option_row.tscn[/code] so it
## renders in the editor; [method configure] fills the picker and wires the change callback.

## Wires the row: [param label_text] over a dropdown of [param options] with [param selected] chosen;
## [param on_change] receives the selected index. Called off-tree right after instantiation, so nodes are
## reached by unique name rather than [code]@onready[/code].
func configure(label_text: String, options: Array, selected: int, on_change: Callable) -> void:
	var label: Label = %Label
	label.text = label_text

	var picker: OptionButton = %Picker
	for i: int in options.size():
		picker.add_item(str(options[i]), i)
	picker.select(selected)
	picker.item_selected.connect(func(index: int) -> void: on_change.call(index))
