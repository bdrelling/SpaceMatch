class_name CatalogBrowser
extends VBoxContainer
## A reusable list of a [Catalog]'s entries as drill-in rows, decoupled from the debug shell so any screen can
## embed it — the debug catalog page ([CatalogView]) wraps one to browse-and-edit, and [CatalogPicker] wraps
## one to choose an entry. Tapping a row emits [signal entry_activated]; the optional trailing "+" row emits
## [signal add_requested]. The host decides what those mean (open an editor, take a selection, add an entry),
## so the browser stays pure UI over the [Catalog] entry contract — no navigation, no [DebugView] dependency.
## Scene-backed by [code]catalog_browser.tscn[/code] (renders in the editor); it pins no theme, inheriting the
## host's (debug.tres inside the debug shell, default.tres in a game screen).

## A row was tapped. The host opens the entry's editor (browse) or takes it as the selection (pick).
signal entry_activated(entry: Resource)
## The trailing "+" row was tapped. Only shown when the browser was built with the add affordance.
signal add_requested()

const SCENE_PATH := "res://ui/catalog_browser/catalog_browser.tscn"

## Text shown when the catalog has no entries — set by the host before the browser enters the tree (a picker
## reads differently than an editor).
var empty_text: String = "Empty."

var _catalog: Catalog
var _show_add: bool = false

## Builds a browser over [param catalog]. When [param show_add] is true, a trailing "+" row emits
## [signal add_requested] — for hosts without their own add affordance (the debug page keeps its header "+",
## so it passes false).
static func create(catalog: Catalog, show_add: bool = false) -> CatalogBrowser:
	var scene: PackedScene = load(SCENE_PATH)
	var browser: CatalogBrowser = scene.instantiate()
	browser.setup(catalog, show_add)
	return browser

## Points the browser at [param catalog]. Use when the browser is instanced declaratively (the [method create]
## path calls this for you). Refreshes immediately if already mounted.
func setup(catalog: Catalog, show_add: bool = false) -> void:
	_catalog = catalog
	_show_add = show_add
	if is_inside_tree():
		refresh()

func _ready() -> void:
	refresh()

## Clears and rebuilds the rows from the catalog's current entries. Call after the entries change (add/remove).
func refresh() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _catalog == null:
		return
	var items := _catalog.entries()
	if items.is_empty():
		var empty := Label.new()
		empty.text = empty_text
		empty.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
		add_child(empty)
	else:
		for entry: Resource in items:
			var e := entry
			add_child(DebugRow.nav(_catalog.entry_title(e), "", func() -> void: entry_activated.emit(e)))
	if _show_add:
		add_child(DebugRow.nav("+ Add", "", func() -> void: add_requested.emit()))
