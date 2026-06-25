class_name StarshipCatalog
extends Catalog
## The catalog of [StarshipBlueprint]s — named ships, each pairing a name with a module-grid layout. Its
## `default.tres` seed holds the standard ship; the editor can add ships and (next step) assign grids.

@export var starships: Array[StarshipBlueprint] = []

const _DEFAULT_PATH := "res://resources/starships/default_starship_blueprint.tres"

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

static func default() -> StarshipCatalog:
	var catalog := StarshipCatalog.new()
	catalog.catalog_name = "Starships"
	var ship: StarshipBlueprint = load(_DEFAULT_PATH)
	if ship != null:
		catalog.starships.append(ship)
	return catalog
