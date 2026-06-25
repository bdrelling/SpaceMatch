# AUTOLOAD: Catalogs
extends Node
## The live, in-memory catalogs the in-game editor edits — modules, module grids, starships, and rules.
## Each loads its generated `all.tres` if one exists, else falls back to a code-built default. Edits mutate
## these instances in place (the board reads the active rules via [DebugConfig.match_rules], which points
## here); persisting edits back to disk lands later.

const _DIR := "res://resources/catalogs/"

var modules: ModuleCatalog
var module_grids: ModuleGridCatalog
var starships: StarshipCatalog
var rules: RuleCatalog

func _ready() -> void:
	modules = _load(_DIR + "module_catalog_all.tres", ModuleCatalog.default) as ModuleCatalog
	module_grids = _load(_DIR + "module_grid_catalog_all.tres", ModuleGridCatalog.default) as ModuleGridCatalog
	starships = _load(_DIR + "starship_catalog_all.tres", StarshipCatalog.default) as StarshipCatalog
	rules = _load(_DIR + "rule_catalog_all.tres", RuleCatalog.default) as RuleCatalog

# The catalog at [param path] if it exists, else the code-built default from [param fallback].
func _load(path: String, fallback: Callable) -> Catalog:
	if ResourceLoader.exists(path):
		var loaded: Catalog = load(path)
		if loaded != null:
			return loaded
	var built: Catalog = fallback.call()
	return built
