class_name ModuleCatalog
extends Catalog
## The catalog of [ModuleBlueprint]s — every module that can be slotted into a grid. Its `default.tres`
## seed gathers the authored module resources; the editor can add and edit modules in memory.

@export var modules: Array[ModuleBlueprint] = []

# The authored module resources the default catalog ships with.
const _DEFAULT_PATHS: Array[String] = [
	"res://resources/items/modules/reactor_item_blueprint.tres",
	"res://resources/items/modules/engine_item_blueprint.tres",
	"res://resources/items/modules/shield_generator_item_blueprint.tres",
	"res://resources/items/modules/sensor_array_item_blueprint.tres",
	"res://resources/items/modules/life_support_item_blueprint.tres",
	"res://resources/items/modules/laser_cannon_item_blueprint.tres",
]

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

# The next free id above the modules already present (ids are 1000+).
func _next_id() -> int:
	var highest := 999
	for module: ModuleBlueprint in modules:
		highest = maxi(highest, module.id)
	return highest + 1

static func default() -> ModuleCatalog:
	var catalog := ModuleCatalog.new()
	catalog.catalog_name = "Modules"
	for path: String in _DEFAULT_PATHS:
		var module: ModuleBlueprint = load(path)
		if module != null:
			catalog.modules.append(module)
	return catalog
