extends GdUnitTestSuite
## [CatalogBrowser] lists a catalog's entries as rows and — decoupled from any navigation or the debug shell —
## emits [signal CatalogBrowser.entry_activated] with the tapped entry. That signal is what lets the same
## component serve as a picker from any screen, so it's the behaviour worth guarding.

# A minimal in-memory catalog with a fixed entry list, so the test never depends on authored content.
class _StubCatalog extends Catalog:
	var items: Array[Resource] = []
	func entries() -> Array:
		return items

func _entry(entry_name: String) -> Resource:
	var resource := Resource.new()
	resource.resource_name = entry_name
	return resource

func _stub(count: int) -> _StubCatalog:
	var catalog := _StubCatalog.new()
	for i: int in count:
		catalog.items.append(_entry("Entry %d" % i))
	return catalog

func test_builds_one_row_per_entry() -> void:
	var catalog := _stub(3)
	var browser: CatalogBrowser = auto_free(CatalogBrowser.create(catalog))
	add_child(browser)
	assert_int(browser.get_child_count()).is_equal(3)

func test_tapping_a_row_emits_entry_activated_with_that_entry() -> void:
	var catalog := _stub(2)
	var browser: CatalogBrowser = auto_free(CatalogBrowser.create(catalog))
	add_child(browser)
	var captured: Array[Resource] = []
	browser.entry_activated.connect(func(entry: Resource) -> void: captured.append(entry))
	(browser.get_child(1) as Button).pressed.emit()
	assert_int(captured.size()).is_equal(1)
	assert_object(captured[0]).is_same(catalog.items[1])

func test_empty_catalog_shows_the_configured_empty_text() -> void:
	var catalog := _stub(0)
	var browser: CatalogBrowser = auto_free(CatalogBrowser.create(catalog))
	browser.empty_text = "Nothing here."
	add_child(browser)
	assert_int(browser.get_child_count()).is_equal(1)
	assert_str((browser.get_child(0) as Label).text).is_equal("Nothing here.")
