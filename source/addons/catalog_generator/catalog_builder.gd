extends RefCounted
## Pure building of the full catalogs: builds each catalog from its data folder and writes the `.tres` under
## [constant OUTPUT_DIR]. The catalog-generator editor plugin is the single caller — on editor open and on
## file add/rename/move. For a no-editor/CI rebuild, run the plugin headless with
## [code]godot --path source --editor --quit[/code]. Uses no editor APIs itself. Only the full "all" catalogs
## live here — partial (curated) catalogs are authored by hand and never touched.

const OUTPUT_DIR := "res://data/catalogs"

const MODULES_DIRECTORY := "res://data/modules"
const MODULE_GRIDS_DIRECTORY := "res://data/module_grids"
const STARSHIPS_DIRECTORY := "res://data/starships"
const RULESETS_DIRECTORY := "res://data/rulesets"
const ABILITY_RESOURCES_DIRECTORY := "res://data/ability_resources"
const STATUSES_DIRECTORY := "res://data/statuses"

const MODULES_OUTPUT := OUTPUT_DIR + "/module_catalog_all.tres"
const MODULE_GRIDS_OUTPUT := OUTPUT_DIR + "/module_grid_catalog_all.tres"
const STARSHIPS_OUTPUT := OUTPUT_DIR + "/starship_catalog_all.tres"
const RULES_OUTPUT := OUTPUT_DIR + "/rule_catalog_all.tres"
const ABILITY_RESOURCES_OUTPUT := OUTPUT_DIR + "/ability_resource_catalog_all.tres"
const STATUSES_OUTPUT := OUTPUT_DIR + "/status_catalog_all.tres"

## The data folders that back a catalog, in build order. The plugin watches these for adds, renames, and moves.
static func directories() -> PackedStringArray:
	return PackedStringArray([
		MODULES_DIRECTORY, MODULE_GRIDS_DIRECTORY, STARSHIPS_DIRECTORY, RULESETS_DIRECTORY,
		ABILITY_RESOURCES_DIRECTORY, STATUSES_DIRECTORY,
	])

## Rebuilds every catalog from disk.
static func build_all() -> void:
	for directory: String in directories():
		build(directory)

## Rebuilds the one catalog gathered from [param directory] (a no-op for an unknown folder).
static func build(directory: String) -> void:
	match directory:
		MODULES_DIRECTORY:
			_save(ModuleCatalog.default(), MODULES_OUTPUT)
		MODULE_GRIDS_DIRECTORY:
			_save(ModuleGridCatalog.default(), MODULE_GRIDS_OUTPUT)
		STARSHIPS_DIRECTORY:
			_save(StarshipCatalog.default(), STARSHIPS_OUTPUT)
		RULESETS_DIRECTORY:
			_save(RuleCatalog.default(), RULES_OUTPUT)
		ABILITY_RESOURCES_DIRECTORY:
			_save(AbilityResourceCatalog.default(), ABILITY_RESOURCES_OUTPUT)
		STATUSES_DIRECTORY:
			_save(StatusCatalog.default(), STATUSES_OUTPUT)

## The sorted `.tres` paths under [param directory] (recursive) — the membership set the plugin diffs to detect
## adds, renames, and moves. A content edit leaves this set unchanged, so it never triggers a rebuild.
static func tres_paths(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var access := DirAccess.open(directory)
	if access == null:
		return paths
	access.list_dir_begin()
	var entry := access.get_next()
	while entry != "":
		var full := directory.path_join(entry)
		if access.current_is_dir():
			paths.append_array(tres_paths(full))
		elif entry.ends_with(".tres"):
			paths.append(full)
		entry = access.get_next()
	access.list_dir_end()
	paths.sort()
	return paths

static func _save(catalog: Catalog, path: String) -> void:
	if catalog == null:
		return
	# Bind this freshly-built catalog to the target path so the save reuses the file's existing uid rather
	# than minting a new one each rebuild (which would churn the file every editor open). We must keep using
	# this fresh instance and never load() the old file: from the @tool plugin a loaded resource's non-@tool
	# script is a placeholder whose methods (regenerate, etc.) can't run in the editor.
	if ResourceLoader.exists(path):
		catalog.take_over_path(path)
	var result := ResourceSaver.save(catalog, path)
	if result != OK:
		push_error("CatalogBuilder: failed to save %s (error %d)." % [path, result])
