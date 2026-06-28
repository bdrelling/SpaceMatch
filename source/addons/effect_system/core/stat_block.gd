class_name StatBlock
extends Resource
## Abstract stats contract. Games subclass it with typed @export fields
## (e.g. [code]StarshipStats extends StatBlock { hull: int, ... }[/code]). Name access bridges to Godot
## [method Object.get] / [method Object.set], so there is no Dictionary and no sync layer: in-game you
## use typed access (ship_stats.hull) and only authored data ever names a stat as a [StringName].

## This block's value for [param stat_name]. Pushes an error and returns 0 when the stat is absent.
func get_stat(stat_name: StringName) -> Variant:
	if stat_name not in stat_names():
		push_error("StatBlock has no stat named '%s'." % stat_name)
		return 0
	return get(stat_name)

## Sets [param stat_name] to [param value].
func set_stat(stat_name: StringName, value: Variant) -> void:
	set(stat_name, value)

## The names of every stat this block declares (its script @export variables).
func stat_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for property: Dictionary in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(property.name)
	return names
