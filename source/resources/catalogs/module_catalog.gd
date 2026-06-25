class_name ModuleCatalog
extends Catalog
## The catalog of [ModuleBlueprint]s — every module that can be slotted into a grid. It gathers every
## authored module resource from its directory; the editor can add and edit modules in memory.

const _DIRECTORY := "res://resources/items/modules"

@export var modules: Array[ModuleBlueprint] = []

func entries() -> Array:
	return modules

func entry_title(entry: Resource) -> String:
	var module := entry as ModuleBlueprint
	if module == null:
		return "Module"
	return module.name if not module.name.is_empty() else "Module #%d" % module.id

func add_new() -> Resource:
	var module := ModuleBlueprint.new()
	module.name = "New Module"
	module.id = _next_id()
	module.stats = StatBlock.new()
	module.shape = PieceShape.from_offsets([Vector2i.ZERO] as Array[Vector2i])
	modules.append(module)
	return module

func remove_entry(entry: Resource) -> void:
	var module := entry as ModuleBlueprint
	if module != null:
		modules.erase(module)

func matches(entry: Resource) -> bool:
	return entry is ModuleBlueprint

# The next free id above the modules already present (ids are 1000+).
func _next_id() -> int:
	var highest := 999
	for module: ModuleBlueprint in modules:
		highest = maxi(highest, module.id)
	return highest + 1

static func default() -> ModuleCatalog:
	var catalog := ModuleCatalog.new()
	catalog.catalog_name = "Modules"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
