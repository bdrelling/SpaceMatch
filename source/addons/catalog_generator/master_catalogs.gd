extends RefCounted
## Pure, editor-agnostic generation of the master "everything" catalogs: builds each catalog from its data
## folder and writes the `.tres` under [constant OUTPUT_DIR]. Shared by the catalog-generator editor plugin
## and the headless [code]tools/regenerate_master_catalogs.gd[/code], so there is one source of truth. Uses no
## editor APIs, so it runs headless. Only the full "all" catalogs live here — partial (curated) catalogs are
## authored by hand and never touched.

const OUTPUT_DIR := "res://data/catalogs"

const MODULES_DIRECTORY := "res://data/modules"
const MODULE_GRIDS_DIRECTORY := "res://data/module_grids"
const STARSHIPS_DIRECTORY := "res://data/starships"

const MODULES_OUTPUT := OUTPUT_DIR + "/module_catalog_all.tres"
const MODULE_GRIDS_OUTPUT := OUTPUT_DIR + "/module_grid_catalog_all.tres"
const STARSHIPS_OUTPUT := OUTPUT_DIR + "/starship_catalog_all.tres"

## The data folders that back a master catalog, in regeneration order. The plugin watches these for adds,
## renames, and moves.
static func directories() -> PackedStringArray:
	return PackedStringArray([MODULES_DIRECTORY, MODULE_GRIDS_DIRECTORY, STARSHIPS_DIRECTORY])

## Rebuilds every master catalog from disk.
static func regenerate_all() -> void:
	for directory: String in directories():
		regenerate(directory)

## Rebuilds the one master catalog gathered from [param directory] (a no-op for an unknown folder).
static func regenerate(directory: String) -> void:
	match directory:
		MODULES_DIRECTORY:
			_save(ModuleCatalog.default(), MODULES_OUTPUT)
		MODULE_GRIDS_DIRECTORY:
			_save(ModuleGridCatalog.default(), MODULE_GRIDS_OUTPUT)
		STARSHIPS_DIRECTORY:
			_save(StarshipCatalog.default(), STARSHIPS_OUTPUT)

## The sorted `.tres` paths under [param directory] (recursive) — the membership set the plugin diffs to detect
## adds, renames, and moves. A content edit leaves this set unchanged, so it never triggers a regenerate.
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
	var result := ResourceSaver.save(catalog, path)
	if result != OK:
		push_error("Master catalogs: failed to save %s (error %d)." % [path, result])
