@tool
extends EditorPlugin
## Editor-only tool that keeps the master "everything" catalogs (under [code]res://data/catalogs/[/code]) in sync
## with the data folders. When a resource is added, renamed, or moved in a watched folder, the matching master
## catalog `.tres` is regenerated; an in-place content edit leaves the folder's file set unchanged and is
## ignored. At runtime the [Catalogs] autoload just loads these `.tres` — nothing scans. See [MasterCatalogs]
## for the generation itself.

const MasterCatalogs := preload("res://addons/catalog_generator/master_catalogs.gd")

# Watched folder -> the `.tres` membership set last seen, so a change can be told from a content edit.
var _known := {}
var _busy := false

func _enter_tree() -> void:
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
	for directory: String in MasterCatalogs.directories():
		_known[directory] = MasterCatalogs.tres_paths(directory)
	# Rebuild on open so the catalogs are always current the moment the editor loads.
	MasterCatalogs.regenerate_all()

func _exit_tree() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		filesystem.filesystem_changed.disconnect(_on_filesystem_changed)

# Regenerates only the catalogs whose folder membership changed (an add, rename, or move). The outputs land in
# res://data/catalogs/, which is not watched, so a regenerate can't retrigger itself.
func _on_filesystem_changed() -> void:
	if _busy:
		return
	_busy = true
	for directory: String in MasterCatalogs.directories():
		var current := MasterCatalogs.tres_paths(directory)
		if current != _known.get(directory):
			_known[directory] = current
			MasterCatalogs.regenerate(directory)
	_busy = false
