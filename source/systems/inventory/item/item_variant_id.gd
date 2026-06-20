class_name ItemVariantId
extends RefCounted
## The deduplication identity of an item: blueprint id plus sorted tags. Stacks merge only when
## their variant ids are equal — so a damaged module never merges with a working one.

var id: int = -1
var tags: Array[Item.Tag] = []

func _init(_id: int = -1, _tags: Array[Item.Tag] = []) -> void:
	id = _id
	tags = _tags.duplicate()
	tags.sort()

func equals(other: ItemVariantId) -> bool:
	return other != null and id == other.id and tags == other.tags
