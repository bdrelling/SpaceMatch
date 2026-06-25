class_name DebugRow
extends RefCounted
## The debug toolkit's row factories — labelled sliders, dropdowns, toggles, text fields, and drill-in
## nav buttons, all touch-sized and aligned the same. Views ([DebugView]) and sections ([DebugSection])
## compose these so every editor page looks consistent and a new control is one call. Pure builders: they
## hold no state, just wire the passed-in callback to the control's change signal and hand back the node.

const ROW_FONT := 32
const _LABEL_WIDTH := 360.0
const _VALUE_WIDTH := 90.0
const _CONTROL_HEIGHT := 56.0

## A labelled slider with a live integer readout; [param on_change] receives the value as the user drags.
static func slider(label_text: String, color: Color, minimum: float, maximum: float, value: float,
		on_change: Callable) -> Control:
	var row := _row()
	row.add_child(_label(label_text, color, _LABEL_WIDTH))

	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = 1
	control.value = value
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.custom_minimum_size = Vector2(0, _CONTROL_HEIGHT)
	row.add_child(control)

	var readout := _label(str(int(value)), Color.WHITE, _VALUE_WIDTH)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)

	control.value_changed.connect(func(new_value: float) -> void:
		readout.text = str(int(new_value))
		on_change.call(new_value))
	return row

## A labelled dropdown; [param on_change] receives the selected index.
static func option(label_text: String, options: Array, selected: int, on_change: Callable) -> Control:
	var row := _row()
	row.add_child(_label(label_text, Color.WHITE, _LABEL_WIDTH))

	var picker := OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 64)
	picker.add_theme_font_size_override("font_size", ROW_FONT)
	for i: int in options.size():
		picker.add_item(str(options[i]), i)
	picker.select(selected)
	picker.item_selected.connect(func(index: int) -> void: on_change.call(index))
	row.add_child(picker)
	return row

## A labelled on/off switch; [param on_change] receives the new state.
static func toggle(label_text: String, value: bool, on_change: Callable) -> Control:
	var row := _row()
	row.add_child(_label(label_text, Color.WHITE, _LABEL_WIDTH))

	var control := CheckButton.new()
	control.focus_mode = Control.FOCUS_NONE
	control.button_pressed = value
	control.custom_minimum_size = Vector2(0, 64)
	control.toggled.connect(func(pressed: bool) -> void: on_change.call(pressed))
	row.add_child(control)
	return row

## A labelled text field; [param on_change] receives the edited text on every keystroke.
static func text(label_text: String, value: String, on_change: Callable) -> Control:
	var row := _row()
	row.add_child(_label(label_text, Color.WHITE, _LABEL_WIDTH))

	var field := LineEdit.new()
	field.text = value
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, 64)
	field.add_theme_font_size_override("font_size", ROW_FONT)
	field.text_changed.connect(func(new_text: String) -> void: on_change.call(new_text))
	row.add_child(field)
	return row

## A full-width button that drills into another view; [param detail] is an optional right-hand hint.
static func nav(label_text: String, detail: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 88)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", ROW_FONT)
	button.text = label_text if detail.is_empty() else "%s    ·  %s" % [label_text, detail]
	button.pressed.connect(func() -> void: on_press.call())
	return button

static func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row

static func _label(label_text: String, color: Color, width: float) -> Label:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", ROW_FONT)
	label.add_theme_color_override("font_color", color)
	return label
