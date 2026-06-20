@tool
class_name Fabricator
extends CraftingStation
## A crafting station that assembles components into modules. Its recipes live in its [RecipeBook]
## (see [CraftingStation]).

const SCENE_PATH := "res://entities/structures/fabricator/fabricator.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)
