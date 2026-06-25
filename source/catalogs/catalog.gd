class_name Catalog
extends Resource
## A named, editable collection of one blueprint type — the in-game editor's unit of content. Subclasses
## hold the strongly-typed Array (so a `.tres` authors correctly) and implement the hooks the editor UI
## ([CatalogView]) calls: list the entries, title one, add a blank, remove one. Edits are in memory;
## persisting back to disk lands later. Each type ships a `default.tres` seed (see [Catalogs]).

@export var catalog_name: String = ""

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
