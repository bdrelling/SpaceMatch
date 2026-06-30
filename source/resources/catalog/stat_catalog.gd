class_name StatCatalog
extends Catalog
## The catalog of [StarshipStat]s — every authored stat (power, damage, hull, ...). Directory-backed: it gathers
## every stat from [code]data/stats/[/code]. A master "everything" catalog meant for runtime lookups and the
## in-game editor.

const _DIRECTORY := "res://data/stats"

@export var stats: Array[StarshipStat] = []

func entries() -> Array:
	return stats

func entry_title(entry: Resource) -> String:
	var stat := entry as StarshipStat
	if stat == null or stat.name.is_empty():
		return "Stat"
	return String(stat.name).capitalize()

func add_new() -> Resource:
	var stat := StarshipStat.new()
	stat.name = &"new_stat"
	stats.append(stat)
	return stat

func remove_entry(entry: Resource) -> void:
	var stat := entry as StarshipStat
	if stat != null:
		stats.erase(stat)

func matches(entry: Resource) -> bool:
	return entry is StarshipStat

static func default() -> StatCatalog:
	var catalog := StatCatalog.new()
	catalog.catalog_name = "Stats"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
