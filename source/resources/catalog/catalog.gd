class_name Catalog
extends Resource
## A named, editable collection of one blueprint type — the in-game editor's unit of content. Subclasses
## hold the strongly-typed Array (so a `.tres` authors correctly) and implement the hooks the editor UI
## ([CatalogView]) calls: list the entries, title one, add a blank, remove one. Edits are in memory;
## persisting back to disk lands later.
##
## A catalog is directory-backed: [member directory] names a folder of authored resources, and
## [method regenerate] rescans it to gather every resource of this catalog's type. Narrower, curated
## catalogs are authored by hand (no directory); [method regenerate] leaves those untouched.

@export var catalog_name: String = ""

## The folder of authored resources this catalog gathers. Empty means the catalog is hand-authored, not
## directory-backed, and [method regenerate] is a no-op.
@export_dir var directory: String = ""

## Rebuilds the entries from [member directory]: scans it (recursively) for resource files, loads each, keeps
## the ones of this catalog's type via [method matches], then orders them ascending by [method entry_sort_key]
## (id, else name, else path) so the catalog reads in id order rather than file-path order. No-op when
## [member directory] is empty, so a hand-authored catalog is never wiped.
func regenerate() -> void:
	if directory.is_empty():
		return
	var collection := entries()
	collection.clear()
	var paths := _resource_paths(directory)
	paths.sort()
	for path: String in paths:
		var resource: Resource = load(path)
		if resource != null and matches(resource):
			collection.append(resource)
	collection.sort_custom(_entries_ascending)

## The entries as an untyped Array — the subclass returns its typed Array. The editor iterates this.
func entries() -> Array:
	return []

## A human label for [param entry], shown in the catalog list. Override per type.
func entry_title(entry: Resource) -> String:
	if entry == null:
		return "—"
	return entry.resource_name

## Appends a fresh blank entry and returns it (for the editor's "+"). Override per type.
func add_new() -> Resource:
	return null

## Removes [param entry] if present. Override per type.
func remove_entry(_entry: Resource) -> void:
	pass

## Whether [param entry] belongs in this catalog — its resource type. Used by [method regenerate] to keep
## only matching resources from [member directory]. Override per type.
func matches(_entry: Resource) -> bool:
	return false

## Sort key for [param entry], ordering [method regenerate]'s collection ascending: the entry's [code]id[/code]
## when it has one, else its [code]name[/code], else its resource path. Override for a custom ordering.
func entry_sort_key(entry: Resource) -> Variant:
	var id_value: Variant = entry.get(&"id")
	if id_value != null:
		return id_value
	var name_value: Variant = entry.get(&"name")
	if name_value != null:
		# As a String: a StringName name compares equal under `<` (no lexicographic order), which would leave a
		# name-keyed catalog unsorted.
		return str(name_value)
	return entry.resource_path

# Ascending comparator over [method entry_sort_key], for [method Array.sort_custom].
func _entries_ascending(a: Resource, b: Resource) -> bool:
	return entry_sort_key(a) < entry_sort_key(b)

# Absolute paths of every resource file under [param search_directory], recursively.
func _resource_paths(search_directory: String) -> Array[String]:
	var paths: Array[String] = []
	var directory_access := DirAccess.open(search_directory)
	if directory_access == null:
		return paths
	directory_access.list_dir_begin()
	var entry := directory_access.get_next()
	while entry != "":
		var full_path := search_directory.path_join(entry)
		if directory_access.current_is_dir():
			paths.append_array(_resource_paths(full_path))
		elif entry.ends_with(".tres"):
			paths.append(full_path)
		entry = directory_access.get_next()
	directory_access.list_dir_end()
	return paths
