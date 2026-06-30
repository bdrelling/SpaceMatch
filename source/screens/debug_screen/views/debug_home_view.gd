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
	var none := func(_entry: Resource) -> DebugView: return null
	var entries: Array[Dictionary] = [
		{"catalog": Catalogs.modules,
			"factory": func(entry: Resource) -> DebugView: return ModuleDetailView.create(entry as ModuleBlueprint)},
		{"catalog": Catalogs.module_grids,
			"factory": func(entry: Resource) -> DebugView: return ModuleGridDetailView.create(entry as ModuleGridBlueprint)},
		{"catalog": Catalogs.starships,
			"factory": func(entry: Resource) -> DebugView: return StarshipDetailView.create(entry as StarshipBlueprint)},
		{"catalog": Catalogs.rules,
			"factory": func(entry: Resource) -> DebugView: return MatchRulesView.create(entry as Ruleset)},
		{"catalog": Catalogs.ability_resources, "factory": none},
		{"catalog": Catalogs.statuses, "factory": none},
		{"catalog": Catalogs.stats, "factory": none},
	]
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: Catalog = a.catalog
		var second: Catalog = b.catalog
		return first.catalog_name < second.catalog_name)
	return entries
