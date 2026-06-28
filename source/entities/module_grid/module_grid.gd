class_name ModuleGrid
extends Node
## A starship's module-grid entity — the [Node] that represents a [ModuleGridState] in the hierarchy (a child of
## the [Starship] whose grid it is). Built from a [ModuleGridBlueprint] via [method create] (stamping the hull
## silhouette and its authored modules), or wrapped around existing state via [method with_state]. Logic reads
## the grid off [member state]; this node makes the grid inspectable and places it in the tree.

const SCENE_PATH := "res://entities/module_grid/module_grid.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

@export var state: ModuleGridState

# The placed modules as child [Module] nodes (one per [member ModuleGridState.modules] entry, sharing the same
# [ModuleState] by reference). Rebuilt from the state whenever it changes, so [member modules] mirrors it.
var _modules: Array[Module] = []

## The placed modules as nodes in the hierarchy. Each wraps a [ModuleState] from [member state]'s modules.
var modules: Array[Module]:
	get: return _modules

#region Blueprinting

## Builds the grid state from [param _blueprint]: stamps the hull silhouette, then its authored modules in
## order (a placement that doesn't fit is skipped). A null blueprint yields an empty grid.
func apply_blueprint(_blueprint: ModuleGridBlueprint) -> void:
	if _blueprint == null:
		_adopt(ModuleGridState.new())
		return
	var grid_state := ModuleGridState.new(_blueprint.columns, _blueprint.rows, 1)
	for cell: Vector2i in _blueprint.cells:
		grid_state.usable_cells[cell] = true
	for placement: ModulePlacement in _blueprint.modules:
		if placement != null and placement.module != null:
			grid_state.place(placement.module, placement.origin, placement.rotation)
	_adopt(grid_state)

static func create(_blueprint: ModuleGridBlueprint) -> ModuleGrid:
	var module_grid: ModuleGrid = SCENE.instantiate()
	module_grid.apply_blueprint(_blueprint)
	return module_grid

## Wraps an existing [param _state] in a fresh node — the load/clone path, where the grid data already exists.
static func with_state(_state: ModuleGridState) -> ModuleGrid:
	var module_grid: ModuleGrid = SCENE.instantiate()
	module_grid._adopt(_state)
	return module_grid

# Points this node at [param grid_state], mounts a [Module] child per placed module, and re-mounts them
# whenever the grid changes (a module placed, moved, or removed).
func _adopt(grid_state: ModuleGridState) -> void:
	state = grid_state
	if state != null and not state.changed.is_connected(_mount_modules):
		state.changed.connect(_mount_modules)
	_mount_modules()

# Frees the prior [Module] children and mounts one per [member ModuleGridState.modules] entry, each wrapping
# the same [ModuleState] the grid holds — so editing through the node or the grid is the same edit.
func _mount_modules() -> void:
	for module: Module in _modules:
		module.queue_free()
	_modules.clear()
	if state == null:
		return
	for module_state: ModuleState in state.modules:
		var module := Module.with_state(module_state)
		add_child(module)
		_modules.append(module)

#endregion
