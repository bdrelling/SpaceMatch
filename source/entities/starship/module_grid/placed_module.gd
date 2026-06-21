class_name PlacedModule
extends RefCounted
## A module as placed on a [ShipModuleGrid]: its [ModuleBlueprint] and the absolute cells it covers.
## A read-only projection of a grid occupant — the grid owns the placement; this is built on read.

var module: ModuleBlueprint
var cells: Array[Vector2i]

func _init(_module: ModuleBlueprint = null, _cells: Array[Vector2i] = []) -> void:
	module = _module
	cells = _cells
