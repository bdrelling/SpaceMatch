extends SceneTree
## One-shot tool: writes the default.tres seed for each catalog from its code-built default(), so the
## catalogs ship as editable resources. Run headless:
##   godot --path source --headless --script res://tools/generate_catalogs.gd
## Re-run to regenerate. Not part of the game.

const _DIR := "res://resources/catalogs"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(_DIR)
	_save(ModuleCatalog.default(), _DIR + "/module_catalog_default.tres")
	_save(ModuleGridCatalog.default(), _DIR + "/module_grid_catalog_default.tres")
	_save(StarshipCatalog.default(), _DIR + "/starship_catalog_default.tres")
	_save(RuleCatalog.default(), _DIR + "/rule_catalog_default.tres")
	quit()

func _save(catalog: Catalog, path: String) -> void:
	var err := ResourceSaver.save(catalog, path)
	print("save %s -> %d" % [path, err])
