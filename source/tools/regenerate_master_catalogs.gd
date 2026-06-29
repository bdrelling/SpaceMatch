extends SceneTree
## Headless (re)generation of the master catalogs — the same logic the editor plugin runs, without opening the
## editor. Used by build/import tooling:
##   godot --path source --headless --script res://tools/regenerate_master_catalogs.gd

const MasterCatalogs := preload("res://addons/catalog_generator/master_catalogs.gd")

func _initialize() -> void:
	MasterCatalogs.regenerate_all()
	quit()
