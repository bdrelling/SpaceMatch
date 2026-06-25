class_name StarshipCatalog
extends Catalog
## The catalog of [StarshipBlueprint]s — named ships, each pairing a name with a module-grid layout. It
## gathers every authored ship from its directory; the editor can add ships and (next step) assign grids.

const _DIRECTORY := "res://resources/starships"

@export var starships: Array[StarshipBlueprint] = []

func entries() -> Array:
	return starships

func entry_title(entry: Resource) -> String:
	var ship := entry as StarshipBlueprint
	if ship == null:
		return "Starship"
	return ship.name if not ship.name.is_empty() else "Starship"

func add_new() -> Resource:
	var ship := StarshipBlueprint.new()
	ship.name = "New Starship"
	starships.append(ship)
	return ship

func remove_entry(entry: Resource) -> void:
	var ship := entry as StarshipBlueprint
	if ship != null:
		starships.erase(ship)

func matches(entry: Resource) -> bool:
	return entry is StarshipBlueprint

static func default() -> StarshipCatalog:
	var catalog := StarshipCatalog.new()
	catalog.catalog_name = "Starships"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
