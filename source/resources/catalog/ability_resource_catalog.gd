class_name AbilityResourceCatalog
extends Catalog
## The catalog of [AbilityResource]s — every spendable resource kind (the game's "mana" pools: damage, scrap,
## warp, ...). Directory-backed: it gathers every authored resource from [code]data/ability_resources/[/code].
## A full catalog of every resource, meant for runtime lookups; these are mostly facts and don't all need
## editor pages.

const _DIRECTORY := "res://data/ability_resources"

@export var ability_resources: Array[AbilityResource] = []

func entries() -> Array:
	return ability_resources

## The [StarshipResource] backing board tile [param tile_kind], or null when no resource maps to that kind.
## Bridges the grid's int tile kind to the resource the encounter/ability/rules layer references.
func for_tile(tile_kind: int) -> StarshipResource:
	for resource: AbilityResource in ability_resources:
		var starship_resource := resource as StarshipResource
		if starship_resource != null and starship_resource.tile_kind == tile_kind:
			return starship_resource
	return null

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
