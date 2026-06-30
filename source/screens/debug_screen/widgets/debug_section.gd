class_name DebugSection
extends VBoxContainer
## A titled group in a debug view, styled like an iOS Settings section: a small, left-aligned header above
## a body of rows. Static — pages stay scannable by grouping related rows, with spacing between sections.
## Scene-backed by [code]debug_section.tscn[/code] so it renders in the editor; built off-tree by
## [method create] so a view can add rows to [method body] before it's mounted. An empty title hides the
## header, for a leading untitled group.

const _SCENE := preload("res://screens/debug_screen/widgets/debug_section.tscn")

var _label_text: String

## Builds a section titled [param label_text]; an empty title shows no header.
static func create(label_text: String = "") -> DebugSection:
	var section := _SCENE.instantiate() as DebugSection
	section._label_text = label_text
	section._refresh()
	return section

func _ready() -> void:
	_refresh()

## The container rows are added to (directly or via [method add_row]).
func body() -> VBoxContainer:
	return %Body

## Appends [param row] to the section body.
func add_row(row: Control) -> void:
	body().add_child(row)

func _header() -> Label:
	return %Header

func _refresh() -> void:
	_header().text = _label_text
	_header().visible = not _label_text.is_empty()
