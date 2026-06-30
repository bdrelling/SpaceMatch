class_name CatalogView
extends DebugView
## The debug page for a [Catalog]: a thin adapter that hosts a reusable [CatalogBrowser] inside the debug
## shell. The browser lists the entries (decoupled from any navigation); this view wires a tapped entry to its
## detail editor — built by the [member _detail_factory] the host supplies — and the header "+" to adding one.
## Generic over every catalog type (modules, grids, starships, rules).

var _catalog: Catalog
# func(entry: Resource) -> DebugView — builds the detail editor for an entry. Supplied by the host.
var _detail_factory: Callable
var _browser: CatalogBrowser

## Builds a page for [param catalog]; [param detail_factory] maps an entry to its editor view.
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
	_browser = CatalogBrowser.create(_catalog)
	_browser.empty_text = "Empty — tap + to add one."
	_browser.entry_activated.connect(_open)
	add_child(_browser)

func _open(entry: Resource) -> void:
	var detail: DebugView = _detail_factory.call(entry)
	if detail != null:
		_push(detail)

func _on_add() -> void:
	var entry: Resource = _catalog.add_new()
	if _browser != null:
		_browser.refresh()
	if entry != null:
		_open(entry)

func _on_regenerate() -> void:
	_catalog.regenerate()
	if _browser != null:
		_browser.refresh()
