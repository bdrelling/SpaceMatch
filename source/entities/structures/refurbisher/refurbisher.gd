@tool
class_name Refurbisher
extends CraftingStation
## A crafting station that restores damaged modules to working condition. Its recipes live in its
## [RecipeBook] (see [CraftingStation]).

const SCENE_PATH := "res://entities/structures/refurbisher/refurbisher.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)
