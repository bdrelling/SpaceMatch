class_name ModuleGridCatalog
extends Catalog
## The catalog of [ModuleGridBlueprint]s — bay layouts (dimensions, hull silhouette, and the modules
## stamped into them). Its `default.tres` seed holds the standard bay; the editor can add grids and
## (next step) arrange modules in them.

@export var grids: Array[ModuleGridBlueprint] = []

const _DEFAULT_PATH := "res://resources/starships/default_module_grid_blueprint.tres"

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

static func default() -> ModuleGridCatalog:
	var catalog := ModuleGridCatalog.new()
	catalog.catalog_name = "Module Grids"
	var grid: ModuleGridBlueprint = load(_DEFAULT_PATH)
	if grid != null:
		catalog.grids.append(grid)
	return catalog
