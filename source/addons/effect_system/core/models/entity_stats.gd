class_name EntityStats
extends Resource
## A collection of stat values keyed by [EntityStat]. Holds whatever stats it is given — no typed subclass required — so
## the same block works for any entity; stats match by key ([member EntityStat.name]), the way a [ResourcePool] matches an
## [AbilityResource]. Games may layer typed-field sugar over it (see [StarshipStats]), but the dictionary is the
## storage and the math lives here. Keys are stat names ([StringName]); values are ints.
@export var values: Dictionary = {}


func _init() -> void:
	# A fresh dict per instance so two blocks never share one (an exported default can be shared). A .tres load
	# overwrites this right after with its authored values.
	values = {}


## This block's value for [param stat] (zero when it holds none).
func get_stat(stat: EntityStat) -> int:
	if stat == null:
		return 0
	var value: int = values.get(stat.name, 0)
	return value


## Sets [param stat]'s value.
func set_stat(stat: EntityStat, value: int) -> void:
	if stat != null:
		values[stat.name] = value


## Sums [param other]'s values into this block, key by key.
func add(other: EntityStats) -> void:
	if other == null:
		return
	for key: StringName in other.values:
		var current: int = values.get(key, 0)
		var addend: int = other.values[key]
		values[key] = current + addend


## The keys this block holds a value for.
func stat_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: StringName in values:
		names.append(key)
	return names
