extends GdUnitTestSuite
## [CatalogPicker] wraps a [CatalogBrowser] for selection: choosing an entry emits
## [signal CatalogPicker.selected] with it, with no dependency on the debug shell — the "pick one" half of the
## reusable catalog UI.

# A minimal in-memory catalog with a fixed entry list, so the test never depends on authored content.
class _StubCatalog extends Catalog:
	var items: Array[Resource] = []
	func entries() -> Array:
		return items

func _entry(entry_name: String) -> Resource:
	var resource := Resource.new()
	resource.resource_name = entry_name
	return resource

func test_choosing_an_entry_emits_selected_with_that_entry() -> void:
	var catalog := _StubCatalog.new()
	catalog.items.append(_entry("Alpha"))
	catalog.items.append(_entry("Beta"))
	var picker: CatalogPicker = auto_free(CatalogPicker.create(catalog))
	add_child(picker)
	var captured: Array[Resource] = []
	picker.selected.connect(func(entry: Resource) -> void: captured.append(entry))
	(picker._browser.get_child(1) as Button).pressed.emit()
	assert_int(captured.size()).is_equal(1)
	assert_object(captured[0]).is_same(catalog.items[1])
