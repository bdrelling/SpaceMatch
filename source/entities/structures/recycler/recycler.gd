@tool
class_name Recycler
extends CraftingStation
## A crafting station that turns scrap into usable items and resources.

const SCENE_PATH := "res://entities/structures/recycler/recycler.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

static func create() -> Recycler:
	return SCENE.instantiate()
