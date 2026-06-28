class_name DebugSection
extends VBoxContainer
## A collapsible group in a debug view: a tappable header that shows or hides its body of rows. Lets a page
## stay a short list of section headers on a phone until you drill into the one you want. Scene-backed by
## [code]debug_section.tscn[/code] so it renders in the editor; built off-tree by [method create] so a view
## can add rows to [method body] before it's mounted. Default collapsed.

const _SCENE := preload("res://scenes/debug_screen/widgets/debug_section.tscn")

var _label_text: String
var _expanded: bool

## Builds a section titled [param label_text], collapsed unless [param expanded].
static func create(label_text: String, expanded: bool = false) -> DebugSection:
	var section := _SCENE.instantiate() as DebugSection
	section._label_text = label_text
	section._expanded = expanded
	section._refresh()
	return section

func _ready() -> void:
	_header().pressed.connect(_toggle)
	_refresh()

## The container rows are added to (directly or via [method add_row]).
func body() -> VBoxContainer:
	return %Body

## Appends [param row] to the section body.
func add_row(row: Control) -> void:
	body().add_child(row)

func _header() -> Button:
	return %Header

func _toggle() -> void:
	_expanded = not _expanded
	_refresh()

func _refresh() -> void:
	_header().text = "%s  %s" % ["▾" if _expanded else "▸", _label_text]
	body().visible = _expanded
