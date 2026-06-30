class_name Module
extends Node
## A placed module entity — the [Node] that represents a [ModuleState] in the hierarchy (a child of the
## [ModuleGrid] it sits in). Built from a [ModuleBlueprint] at a placement via [method create], or wrapped
## around existing state via [method with_state]. The grid shares the same [ModuleState] by reference, so an
## edit through the module or the grid is the same edit.

const SCENE_PATH := "res://entities/module/module.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

@export var state: ModuleState

#region Blueprinting

## Builds the module's state from [param _blueprint] — copying its authored profile (see [method
## ModuleState.create]). The module is position-free; a grid assigns it a placement when it's slotted (see
## [member ModuleGridState.placements]).
func apply_blueprint(_blueprint: ModuleBlueprint) -> void:
	state = ModuleState.create(_blueprint)

static func create(_blueprint: ModuleBlueprint) -> Module:
	var module: Module = SCENE.instantiate()
	module.apply_blueprint(_blueprint)
	return module

## Wraps an existing [param _state] in a fresh node — the load/clone path, or when a [ModuleGrid] mounts the
## modules already in its state.
static func with_state(_state: ModuleState) -> Module:
	var module: Module = SCENE.instantiate()
	module.state = _state
	return module

#endregion
