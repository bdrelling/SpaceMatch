class_name DebugRow
extends RefCounted
## The debug toolkit's row factories — labelled sliders, dropdowns, toggles, text fields, and drill-in
## nav buttons, all touch-sized and aligned the same. Views ([DebugView]) and sections ([DebugSection])
## compose these so every editor page looks consistent and a new control is one call. Each row type is its
## own scene (under [code]rows/[/code]) so it renders in the editor; these builders instantiate the matching
## scene, configure it with the passed-in values and callback, and hand back the node.

const ROW_FONT := 32

const _SLIDER_SCENE := preload("res://screens/debug_screen/widgets/rows/slider_row.tscn")
const _OPTION_SCENE := preload("res://screens/debug_screen/widgets/rows/option_row.tscn")
const _TOGGLE_SCENE := preload("res://screens/debug_screen/widgets/rows/toggle_row.tscn")
const _TEXT_SCENE := preload("res://screens/debug_screen/widgets/rows/text_row.tscn")
const _COLOR_SCENE := preload("res://screens/debug_screen/widgets/rows/color_row.tscn")
const _NAV_SCENE := preload("res://screens/debug_screen/widgets/rows/nav_row.tscn")

## A labelled slider with a live integer readout; [param on_change] receives the value as the user drags.
static func slider(label_text: String, color: Color, minimum: float, maximum: float, value: float,
		on_change: Callable) -> Control:
	var row := _SLIDER_SCENE.instantiate() as DebugSliderRow
	row.configure(label_text, color, minimum, maximum, value, on_change)
	return row

## A labelled dropdown; [param on_change] receives the selected index.
static func option(label_text: String, options: Array, selected: int, on_change: Callable) -> Control:
	var row := _OPTION_SCENE.instantiate() as DebugOptionRow
	row.configure(label_text, options, selected, on_change)
	return row

## A labelled on/off switch; [param on_change] receives the new state.
static func toggle(label_text: String, value: bool, on_change: Callable) -> Control:
	var row := _TOGGLE_SCENE.instantiate() as DebugToggleRow
	row.configure(label_text, value, on_change)
	return row

## A labelled text field; [param on_change] receives the edited text on every keystroke.
static func text(label_text: String, value: String, on_change: Callable) -> Control:
	var row := _TEXT_SCENE.instantiate() as DebugTextRow
	row.configure(label_text, value, on_change)
	return row

## A labelled colour picker; [param on_change] receives the chosen [Color].
static func color(label_text: String, value: Color, on_change: Callable) -> Control:
	var row := _COLOR_SCENE.instantiate() as DebugColorRow
	row.configure(label_text, value, on_change)
	return row

## A full-width button that drills into another view; [param detail] is an optional right-hand hint.
static func nav(label_text: String, detail: String, on_press: Callable) -> Button:
	var button := _NAV_SCENE.instantiate() as DebugNavRow
	button.configure(label_text, detail, on_press)
	return button
