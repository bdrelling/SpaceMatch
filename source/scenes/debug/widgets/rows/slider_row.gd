class_name DebugSliderRow
extends HBoxContainer
## A labelled slider with a live integer readout, used by [method DebugRow.slider]. Scene-backed by
## [code]slider_row.tscn[/code] so it renders in the editor; [method configure] applies the label, range,
## value, and change callback. The readout updates as the user drags.

## Wires the row: [param label_text] tinted [param color], slider range [param minimum]–[param maximum]
## seeded at [param value]; [param on_change] receives the value as the user drags. Called off-tree right
## after instantiation, so nodes are reached by unique name rather than [code]@onready[/code].
func configure(label_text: String, color: Color, minimum: float, maximum: float, value: float,
		on_change: Callable) -> void:
	var label: Label = %Label
	label.text = label_text
	label.add_theme_color_override("font_color", color)

	var slider: HSlider = %Slider
	slider.min_value = minimum
	slider.max_value = maximum
	slider.value = value

	var readout: Label = %Readout
	readout.text = str(int(value))

	slider.value_changed.connect(func(new_value: float) -> void:
		readout.text = str(int(new_value))
		on_change.call(new_value))
