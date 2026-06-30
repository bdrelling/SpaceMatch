class_name StatBlock
extends Resource
## A collection of stat values keyed by [Stat]. Holds whatever stats it is given — no typed subclass required — so
## the same block works for any entity; stats match by key ([member Stat.name]), the way a [ResourcePool] matches an
## [AbilityResource]. Games may layer typed-field sugar over it (see [StarshipStats]), but the dictionary is the
## storage and the math lives here.

## Stat value by key ([member Stat.name]). The stored collection; read and written via [method get_stat] /
## [method set_stat], summed by [method add].
@export var values: Dictionary[StringName, int] = {}


## This block's value for [param stat] (zero when it holds none).
func get_stat(stat: Stat) -> int:
	return values.get(stat.name, 0) if stat != null else 0


## Sets [param stat]'s value.
func set_stat(stat: Stat, value: int) -> void:
	if stat != null:
		values[stat.name] = value


## Sums [param other]'s values into this block, key by key.
func add(other: StatBlock) -> void:
	if other == null:
		return
	for key: StringName in other.values:
		values[key] = values.get(key, 0) + other.values[key]


## The keys this block holds a value for.
func stat_names() -> Array[StringName]:
	return values.keys()
