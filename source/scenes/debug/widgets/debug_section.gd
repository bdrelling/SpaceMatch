class_name DebugSection
extends VBoxContainer
## A collapsible group in a debug view: a tappable header that shows or hides its body of rows. Lets a page
## stay a short list of section headers on a phone until you drill into the one you want. Built off-tree by
## [method create] so a view can add rows to [method body] before it's mounted. Default collapsed.

const _HEADER_FONT := 36

var _body: VBoxContainer
var _header: Button
var _label_text: String
var _expanded: bool

## Builds a section titled [param label_text], collapsed unless [param expanded].
static func create(label_text: String, expanded: bool = false) -> DebugSection:
	var section := DebugSection.new()
	section._label_text = label_text
	section._expanded = expanded
	section._build()
	return section

func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_header = Button.new()
	_header.focus_mode = Control.FOCUS_NONE
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.custom_minimum_size = Vector2(0, 72)
	_header.add_theme_font_size_override("font_size", _HEADER_FONT)
	_header.pressed.connect(_toggle)
	add_child(_header)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	add_child(_body)

	_refresh()

## The container rows are added to (directly or via [method add_row]).
func body() -> VBoxContainer:
	return _body

## Appends [param row] to the section body.
func add_row(row: Control) -> void:
	_body.add_child(row)

func _toggle() -> void:
	_expanded = not _expanded
	_refresh()

func _refresh() -> void:
	_header.text = "%s  %s" % ["▾" if _expanded else "▸", _label_text]
	_body.visible = _expanded
