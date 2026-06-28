class_name StarshipCatalog
extends Catalog
## The catalog of [StarshipBlueprint]s — named starships, each pairing a name with a module-grid layout. It
## gathers every authored starship from its directory; the editor can add starships and (next step) assign grids.

const _DIRECTORY := "res://data/starships"

@export var starships: Array[StarshipBlueprint] = []

func entries() -> Array:
	return starships

func entry_title(entry: Resource) -> String:
	var starship := entry as StarshipBlueprint
	if starship == null:
		return "Starship"
	return starship.name if not starship.name.is_empty() else "Starship"

func add_new() -> Resource:
	var starship := StarshipBlueprint.new()
	starship.name = "New Starship"
	starships.append(starship)
	return starship

func remove_entry(entry: Resource) -> void:
	var starship := entry as StarshipBlueprint
	if starship != null:
		starships.erase(starship)

func matches(entry: Resource) -> bool:
	return entry is StarshipBlueprint

static func default() -> StarshipCatalog:
	var catalog := StarshipCatalog.new()
	catalog.catalog_name = "Starships"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
