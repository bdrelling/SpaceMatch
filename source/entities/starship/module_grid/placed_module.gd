class_name PlacedModule
extends RefCounted
## A module as placed on a [ModuleGrid]: its [ModuleBlueprint], the absolute cells it covers, and whether
## it's enabled. A read-only projection of a grid occupant — the grid owns the placement; this is built on
## read. A module is enabled only when every cell it covers is enabled; a single disabled cell deactivates
## the whole module, so it stops counting toward the ship's stats (see [method ModuleGrid.profile]).

var module: ModuleBlueprint
var cells: Array[Vector2i]
## False when any cell this module covers is disabled. A disabled module contributes nothing to the profile.
var enabled: bool

func _init(_module: ModuleBlueprint = null, _cells: Array[Vector2i] = [], _enabled: bool = true) -> void:
	module = _module
	cells = _cells
	enabled = _enabled
