extends GdUnitTestSuite
## Tests LootTable.roll — typed weighted selection over the wrapped WeightedCollection.

func _item(id: int) -> ItemBlueprint:
	var blueprint := ItemBlueprint.new()
	blueprint.id = id
	blueprint.name = "Item %d" % id
	return blueprint

func _entry(value: Resource, weight: float) -> WeightedEntry:
	var entry := WeightedEntry.new()
	entry.value = value
	entry.weight = weight
	return entry

func _table(entries: Array[WeightedEntry]) -> LootTable:
	var collection := WeightedCollection.new()
	collection.entries = entries
	var table := LootTable.new()
	table._items = collection
	return table

func test_empty_table_returns_null() -> void:
	var entries: Array[WeightedEntry] = []
	assert_object(_table(entries).roll()).is_null()

func test_table_of_only_invalid_entries_returns_null() -> void:
	# Null item, zero weight, and negative weight are all ignored.
	var entries: Array[WeightedEntry] = [_entry(null, 5.0), _entry(_item(1), 0.0), _entry(_item(2), -3.0)]
	assert_object(_table(entries).roll()).is_null()

func test_single_item_is_always_returned() -> void:
	var entries: Array[WeightedEntry] = [_entry(_item(7), 1.0)]
	var table := _table(entries)
	for _i: int in 50:
		assert_int(table.roll().id).is_equal(7)

func test_roll_only_returns_table_members() -> void:
	var entries: Array[WeightedEntry] = [_entry(_item(1), 5.0), _entry(_item(2), 1.0)]
	var table := _table(entries)
	for _i: int in 100:
		var rolled: ItemBlueprint = table.roll()
		assert_bool(rolled.id == 1 or rolled.id == 2).is_true()

func test_zero_weight_item_is_never_returned() -> void:
	var entries: Array[WeightedEntry] = [_entry(_item(1), 10.0), _entry(_item(2), 0.0)]
	var table := _table(entries)
	for _i: int in 100:
		assert_int(table.roll().id).is_equal(1)
