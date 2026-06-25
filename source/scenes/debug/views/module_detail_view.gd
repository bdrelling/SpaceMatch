class_name ModuleDetailView
extends DebugView
## Editor for one [ModuleBlueprint] — its name, id, and the [StatBlock] it contributes (every stat as a
## slider, introspected so new stats appear automatically). Edits the module in place. The footprint
## ([PieceShape]) is shown read-only for now; editing it comes with grid arrange.

var _module: ModuleBlueprint

static func create(module: ModuleBlueprint) -> ModuleDetailView:
	var view := ModuleDetailView.new()
	view._module = module
	return view

func title() -> String:
	if _module == null or _module.name.is_empty():
		return "Module"
	return _module.name

func _build() -> void:
	if _module == null:
		return
	var module := _module

	add_child(DebugRow.text("Name", module.name,
		func(value: String) -> void: module.name = value))
	add_child(DebugRow.slider("ID", Color.WHITE, 1000, 1099, maxi(module.id, 1000),
		func(value: float) -> void: module.id = int(value)))

	var shape_heading := Label.new()
	shape_heading.text = "Shape"
	shape_heading.add_theme_font_size_override("font_size", 36)
	add_child(shape_heading)
	var initial: Array[Vector2i] = module.shape.offsets if module.shape != null else ([] as Array[Vector2i])
	add_child(DebugShapeEditor.create(initial, module.color, func(offsets: Array[Vector2i]) -> void:
		module.shape = PieceShape.from_offsets(offsets)))

	var heading := Label.new()
	heading.text = "Stats"
	heading.add_theme_font_size_override("font_size", 36)
	add_child(heading)

	if module.stats == null:
		module.stats = StatBlock.new()
	var stats := module.stats
	for prop: Dictionary in stats.get_property_list():
		var usage: int = prop.usage
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var prop_type: int = prop.type
		if prop_type != TYPE_INT:
			continue
		var s := stats
		var p: String = prop.name
		var current: int = s.get(p)
		add_child(DebugRow.slider(p.capitalize(), Color.WHITE, -10, 10, current,
			func(value: float) -> void: s.set(p, int(value))))
