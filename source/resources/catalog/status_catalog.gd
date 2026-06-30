class_name StatusCatalog
extends Catalog
## The catalog of [Status] definitions — every authored status effect (shield, dodge, target lock, ...).
## Directory-backed: it gathers every status from [code]data/statuses/[/code]. A full catalog of every status,
## meant for runtime lookups; these are mostly facts and don't all need editor pages.

const _DIRECTORY := "res://data/statuses"

@export var statuses: Array[Status] = []

func entries() -> Array:
	return statuses

func entry_title(entry: Resource) -> String:
	var status := entry as Status
	if status == null or status.name.is_empty():
		return "Status"
	return String(status.name).capitalize()

func add_new() -> Resource:
	var status := Status.new()
	status.name = &"new_status"
	statuses.append(status)
	return status

func remove_entry(entry: Resource) -> void:
	var status := entry as Status
	if status != null:
		statuses.erase(status)

func matches(entry: Resource) -> bool:
	return entry is Status

static func default() -> StatusCatalog:
	var catalog := StatusCatalog.new()
	catalog.catalog_name = "Statuses"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
