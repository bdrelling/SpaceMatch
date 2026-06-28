class_name CatalogView
extends DebugView
## Lists a [Catalog]'s entries as drill-in rows, with a "+" to add a new one. Tapping an entry opens its
## detail editor — built by the [member _detail_factory] the host supplies, so catalogs stay UI-free.
## Generic over every catalog type (modules, grids, starships, rules).

var _catalog: Catalog
# func(entry: Resource) -> DebugView — builds the detail editor for an entry. Supplied by the host.
var _detail_factory: Callable

## Builds a list view of [param catalog]; [param detail_factory] maps an entry to its editor view.
static func create(catalog: Catalog, detail_factory: Callable) -> CatalogView:
	var view := CatalogView.new()
	view._catalog = catalog
	view._detail_factory = detail_factory
	return view

func title() -> String:
	return _catalog.catalog_name if _catalog != null else "Catalog"

func action() -> Button:
	var button := Button.new()
	button.text = "+"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(64, 0)
	button.add_theme_font_size_override("font_size", 40)
	button.pressed.connect(_on_add)
	return button

func _build() -> void:
	if _catalog == null:
		return
	if not _catalog.directory.is_empty():
		add_child(DebugRow.nav("Regenerate from disk", "", _on_regenerate))
	var items := _catalog.entries()
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Empty — tap + to add one."
		empty.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
		add_child(empty)
		return
	for entry: Resource in items:
		var e := entry
		add_child(DebugRow.nav(_catalog.entry_title(e), "", func() -> void: _open(e)))

func _open(entry: Resource) -> void:
	var detail: DebugView = _detail_factory.call(entry)
	if detail != null:
		_push(detail)

func _on_add() -> void:
	var entry: Resource = _catalog.add_new()
	rebuild()
	if entry != null:
		_open(entry)

func _on_regenerate() -> void:
	_catalog.regenerate()
	rebuild()
