@tool
class_name Chest
extends Structure
## A storage structure: interacting opens its inventory grid so the player can move
## stacks in and out (see [ChestGridInventoryPanel]).

const SCENE_PATH := "res://entities/structures/chest/chest.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

@onready var inventory: Inventory = %Inventory

static func create() -> Chest:
	return SCENE.instantiate()
