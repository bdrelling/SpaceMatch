class_name ModuleDetailView
extends RefCounted
## Builds the editor for one [ModuleBlueprint] as a configured [ResourceEditor]: the generic form handles the
## scalar fields (name, id, colour) and lists the granted abilities/rules, while two escape-hatch fields drop in
## bespoke controls — the footprint as a [DebugShapeEditor] and the contributed [StarshipStats] as a block of
## per-stat sliders. Edits the module in place.

static func create(module: ModuleBlueprint) -> ResourceEditor:
	if module.stats == null:
		module.stats = StarshipStats.new()
	return ResourceEditor.create(module, _title(module)) \
		.with_range("id", 1000, 1099) \
		.with_custom_field("shape", func(resource: Resource) -> Control: return ModuleDetailView._shape_field(resource)) \
		.with_custom_field("stats", func(resource: Resource) -> Control: return ModuleDetailView._stats_field(resource))

static func _title(module: ModuleBlueprint) -> String:
	return module.name if not module.name.is_empty() else "Module"

# The footprint as an interactive grid editor, grouped under a "Shape" header.
static func _shape_field(resource: Resource) -> Control:
	var module := resource as ModuleBlueprint
	var initial: Array[Vector2i] = module.shape.offsets if module.shape != null else ([] as Array[Vector2i])
	var section := DebugSection.create("Shape")
	section.add_row(DebugShapeEditor.create(initial, module.color, func(offsets: Array[Vector2i]) -> void:
		module.shape = PieceShape.from_offsets(offsets)))
	return section

# The contributed stats as a "Stats" block of per-stat sliders, introspected so new stats appear automatically.
static func _stats_field(resource: Resource) -> Control:
	var module := resource as ModuleBlueprint
	var stats := module.stats
	var section := DebugSection.create("Stats")
	for prop: Dictionary in stats.get_property_list():
		var usage: int = prop.usage
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if prop.type != TYPE_INT:
			continue
		var s := stats
		var p: String = prop.name
		var current: int = s.get(p)
		section.add_row(DebugRow.slider(p.capitalize(), Color.WHITE, -10, 10, current,
			func(value: float) -> void: s.set(p, int(value))))
	return section
