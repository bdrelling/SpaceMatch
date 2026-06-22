class_name ModuleGridGenerator
extends RefCounted
## Stateless factory: builds a [ModuleGrid] from a [ModuleGridBlueprint], stamping the silhouette via
## matchbox's [ShapedGridGenerator].

static func generate(blueprint: ModuleGridBlueprint) -> ModuleGrid:
	var module_grid := ModuleGrid.new()
	if blueprint == null:
		module_grid.grid = GridState.new()
		return module_grid
	var shaped := ShapedGridGenerator.new()
	shaped.width = blueprint.columns
	shaped.height = blueprint.rows
	shaped.usable_cells = blueprint.cells
	module_grid.grid = shaped.generate()
	for placement: ModulePlacement in blueprint.modules:
		if placement != null and placement.module != null:
			module_grid.place(placement.module, placement.origin, placement.rotation)
	return module_grid
