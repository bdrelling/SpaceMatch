class_name ModuleGridCatalog
extends Catalog
## The catalog of [ModuleGridBlueprint]s — bay layouts (dimensions, hull silhouette, and the modules
## stamped into them). It gathers every authored bay from its directory; the editor can add grids and
## (next step) arrange modules in them.

const _DIRECTORY := "res://resources/starships"

@export var grids: Array[ModuleGridBlueprint] = []

func entries() -> Array:
	return grids

func entry_title(entry: Resource) -> String:
	var grid := entry as ModuleGridBlueprint
	if grid == null:
		return "Grid"
	return "%d×%d · %d modules" % [grid.columns, grid.rows, grid.modules.size()]

func add_new() -> Resource:
	var grid := ModuleGridBlueprint.new()
	grids.append(grid)
	return grid

func remove_entry(entry: Resource) -> void:
	var grid := entry as ModuleGridBlueprint
	if grid != null:
		grids.erase(grid)

func matches(entry: Resource) -> bool:
	return entry is ModuleGridBlueprint

static func default() -> ModuleGridCatalog:
	var catalog := ModuleGridCatalog.new()
	catalog.catalog_name = "Module Grids"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
