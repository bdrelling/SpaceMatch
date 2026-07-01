class_name DebugHomeView
extends DebugView
## The debug root — the editor's home, grouped like iOS Settings. A leading untitled group holds the tools
## that don't browse a catalog (Board, Selection, Abilities); the "Data" group lists every [Catalog] from
## [Catalogs] alphabetically, each drilling into its entries.

func title() -> String:
	return "Debug"

func _build() -> void:
	add_theme_constant_override("separation", 32)

	var tools := DebugSection.create()
	tools.add_row(DebugRow.nav("Board", "", func() -> void: _push(MatchConfigView.new())))
	tools.add_row(DebugRow.nav("Selection", "", func() -> void: _push(SelectionRuleView.new())))
	tools.add_row(DebugRow.nav("Abilities", "", func() -> void: _push(AbilitiesView.new())))
	add_child(tools)

	var data := DebugSection.create("Data")
	for entry: Dictionary in _data_catalogs():
		var catalog: Catalog = entry.catalog
		var factory: Callable = entry.factory
		data.add_row(DebugRow.nav(catalog.catalog_name, "", func() -> void:
			_push(CatalogView.create(catalog, factory))))
	add_child(data)

# Every catalog paired with the detail editor for its entries, sorted by display name. Catalogs without an
# editor get a null factory — [CatalogView] lists their entries but won't drill into one (browse-only).
func _data_catalogs() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"catalog": Catalogs.modules,
			"factory": func(entry: Resource) -> DebugView: return ModuleDetailView.create(entry as ModuleBlueprint)},
		{"catalog": Catalogs.module_grids,
			"factory": func(entry: Resource) -> DebugView: return ModuleGridDetailView.create(entry as ModuleGridBlueprint)},
		{"catalog": Catalogs.starships,
			"factory": func(entry: Resource) -> DebugView: return StarshipDetailView.create(entry as StarshipBlueprint)},
		{"catalog": Catalogs.rules,
			"factory": func(entry: Resource) -> DebugView: return MatchRulesView.create(entry as Ruleset)},
		{"catalog": Catalogs.ability_resources, "factory": _generic_editor(Catalogs.ability_resources, {"id": [-1, 40]})},
		{"catalog": Catalogs.statuses, "factory": _generic_editor(Catalogs.statuses, {"cap": [0, 20]})},
		{"catalog": Catalogs.stats, "factory": _generic_editor(Catalogs.stats, {"id": [0, 99]})},
	]
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: Catalog = a.catalog
		var second: Catalog = b.catalog
		return first.catalog_name < second.catalog_name)
	return entries

# A detail-editor factory backed by the generic [ResourceEditor], for catalogs whose entries are plain data
# with no bespoke editor. The tapped entry's catalog title becomes the page header; [param ranges] gives named
# numeric fields their slider bounds (property -> [min, max]).
func _generic_editor(catalog: Catalog, ranges: Dictionary = {}) -> Callable:
	return func(entry: Resource) -> DebugView:
		var editor := ResourceEditor.create(entry, catalog.entry_title(entry))
		for property: String in ranges:
			var span: Array = ranges[property]
			var minimum: float = span[0]
			var maximum: float = span[1]
			editor.with_range(property, minimum, maximum)
		return editor
