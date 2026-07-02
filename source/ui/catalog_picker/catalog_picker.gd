class_name CatalogPicker
extends VBoxContainer
## Picks one entry from a [Catalog] — a [CatalogBrowser] wired for selection. Drop into any screen that needs
## the player or designer to choose a catalog entry; it emits [signal selected] with the chosen entry and has
## no dependency on the debug shell. (Browsing-to-edit is the debug page's job; this is the "pick one" half.)
## Scene-backed by [code]catalog_picker.tscn[/code], which instances the browser as a child; pins no theme,
## inheriting the host's.

#region Signals
## An entry was chosen.
signal selected(entry: Resource)
#endregion

#region Constants
const SCENE_PATH := "res://ui/catalog_picker/catalog_picker.tscn"
#endregion

#region Properties
var _catalog: Catalog

@onready var _browser: CatalogBrowser = %Browser
#endregion


#region Methods
## Builds a picker over [param catalog].
static func create(catalog: Catalog) -> CatalogPicker:
	var scene: PackedScene = load(SCENE_PATH)
	var picker: CatalogPicker = scene.instantiate()
	picker._catalog = catalog
	return picker


func _ready() -> void:
	_browser.empty_text = "Nothing to choose yet."
	_browser.entry_activated.connect(func(entry: Resource) -> void: selected.emit(entry))
	_browser.setup(_catalog)
#endregion
