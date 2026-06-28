class_name DebugHomeView
extends DebugView
## The debug root — the list of editor pages. The spine of the in-game editor: each entry drills into a
## domain's catalog editor. Modules / Module Grids / Starships / Rules browse their [Catalog]; Abilities
## edits the active rules' abilities.

func title() -> String:
	return "Debug"

func _build() -> void:
	add_child(DebugRow.nav("Board", "", func() -> void: _push(MatchConfigView.new())))
	add_child(DebugRow.nav("Selection", "", func() -> void: _push(SelectionRuleView.new())))
	add_child(DebugRow.nav("Abilities", "", func() -> void: _push(AbilitiesView.new())))
	add_child(DebugRow.nav("Modules", "", func() -> void:
		_push(CatalogView.create(Catalogs.modules,
			func(entry: Resource) -> DebugView: return ModuleDetailView.create(entry as ModuleBlueprint)))))
	add_child(DebugRow.nav("Module Grids", "", func() -> void:
		_push(CatalogView.create(Catalogs.module_grids,
			func(entry: Resource) -> DebugView: return ModuleGridDetailView.create(entry as ModuleGridBlueprint)))))
	add_child(DebugRow.nav("Starships", "", func() -> void:
		_push(CatalogView.create(Catalogs.starships,
			func(entry: Resource) -> DebugView: return StarshipDetailView.create(entry as StarshipBlueprint)))))
	add_child(DebugRow.nav("Rules", "", func() -> void:
		_push(CatalogView.create(Catalogs.rules,
			func(entry: Resource) -> DebugView: return MatchRulesView.create(entry as Ruleset)))))
