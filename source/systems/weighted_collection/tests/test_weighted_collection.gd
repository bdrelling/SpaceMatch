extends GdUnitTestSuite
## Tests WeightedCollection.pick — returns a member value by weight, filters invalid, handles empty.

func _entry(value: Resource, weight: float) -> WeightedEntry:
	var entry := WeightedEntry.new()
	entry.value = value
	entry.weight = weight
	return entry

func _collection(entries: Array[WeightedEntry]) -> WeightedCollection:
	var collection := WeightedCollection.new()
	collection.entries = entries
	return collection

func test_empty_collection_returns_null() -> void:
	var entries: Array[WeightedEntry] = []
	assert_object(_collection(entries).pick()).is_null()

func test_invalid_entries_return_null() -> void:
	# Zero/negative weight and a null payload are all ignored.
	var entries: Array[WeightedEntry] = [_entry(Resource.new(), 0.0), _entry(Resource.new(), -2.0), _entry(null, 5.0)]
	assert_object(_collection(entries).pick()).is_null()

func test_zero_weight_entry_is_never_picked() -> void:
	var keep := Resource.new()
	var entries: Array[WeightedEntry] = [_entry(keep, 10.0), _entry(Resource.new(), 0.0)]
	var collection := _collection(entries)
	for _i: int in 100:
		assert_object(collection.pick()).is_same(keep)

func test_pick_returns_a_member_value() -> void:
	var a := Resource.new()
	var b := Resource.new()
	var entries: Array[WeightedEntry] = [_entry(a, 5.0), _entry(b, 1.0)]
	var collection := _collection(entries)
	for _i: int in 100:
		var picked := collection.pick()
		assert_bool(picked == a or picked == b).is_true()
