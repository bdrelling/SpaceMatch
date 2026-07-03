class_name AbilityResourceCatalog
extends Catalog
## The catalog of [AbilityResource]s — every spendable resource kind (the game's "mana" pools: combat, scrap,
## warp, ...). Directory-backed: it gathers every authored resource from [code]data/ability_resources/[/code].
## A full catalog of every resource, meant for runtime lookups; these are mostly facts and don't all need
## editor pages. Board representation lives on [Tile], not here — a resource no longer owns a tile kind.

const _DIRECTORY := "res://data/ability_resources"

@export var ability_resources: Array[AbilityResource] = []


func entries() -> Array:
	return ability_resources


func entry_title(entry: Resource) -> String:
	var resource := entry as AbilityResource
	if resource == null or resource.name.is_empty():
		return "Resource"
	return String(resource.name).capitalize()


func add_new() -> Resource:
	var resource := AbilityResource.new()
	resource.name = &"new_resource"
	ability_resources.append(resource)
	return resource


func remove_entry(entry: Resource) -> void:
	var resource := entry as AbilityResource
	if resource != null:
		ability_resources.erase(resource)


func matches(entry: Resource) -> bool:
	return entry is AbilityResource


static func default() -> AbilityResourceCatalog:
	var catalog := AbilityResourceCatalog.new()
	catalog.catalog_name = "Ability Resources"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
