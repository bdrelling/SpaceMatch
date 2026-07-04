# AUTOLOAD: Catalogs
extends Node
## The live, in-memory catalogs — every authored resource of a type, gathered from its data folder. The
## catalog generator plugin keeps the `all.tres` files current; each loads its generated `all.tres` if one
## exists, else falls back to a code-built default that rebuilds from the folder on the spot. Some catalogs are
## editor-facing (modules, starships, rules); others are just facts read at runtime (ability resources,
## statuses). The board reads the active ruleset via [DebugConfig.match_ruleset], which points here.

const _DIR := "res://data/catalogs/"

var modules: ModuleCatalog
var module_grids: ModuleGridCatalog
var starships: StarshipCatalog
var rules: RuleCatalog
var match_configs: MatchConfigCatalog
var ability_resources: AbilityResourceCatalog
var tiles: TileCatalog
var statuses: StatusCatalog
var stats: StatCatalog


func _ready() -> void:
	modules = _load(_DIR + "module_catalog_all.tres", ModuleCatalog.default) as ModuleCatalog
	module_grids = _load(_DIR + "module_grid_catalog_all.tres", ModuleGridCatalog.default) as ModuleGridCatalog
	starships = _load(_DIR + "starship_catalog_all.tres", StarshipCatalog.default) as StarshipCatalog
	rules = _load(_DIR + "rule_catalog_all.tres", RuleCatalog.default) as RuleCatalog
	match_configs = _load(_DIR + "match_config_catalog_all.tres", MatchConfigCatalog.default) as MatchConfigCatalog
	ability_resources = _load(_DIR + "ability_resource_catalog_all.tres", AbilityResourceCatalog.default) as AbilityResourceCatalog
	tiles = _load(_DIR + "tile_catalog_all.tres", TileCatalog.default) as TileCatalog
	statuses = _load(_DIR + "status_catalog_all.tres", StatusCatalog.default) as StatusCatalog
	stats = _load(_DIR + "stat_catalog_all.tres", StatCatalog.default) as StatCatalog


# The catalog at [param path] if it exists, else the code-built default from [param fallback].
func _load(path: String, fallback: Callable) -> Catalog:
	if ResourceLoader.exists(path):
		var loaded: Catalog = load(path)
		if loaded != null:
			return loaded
	var built: Catalog = fallback.call()
	return built
