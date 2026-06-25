class_name Background
extends TextureRect
## The app's shared cosmos backdrop — the blue/purple gradient ([code]space_background.tres[/code]) drawn
## full-bleed behind a screen. One reusable component so every screen (encounter, menu, debug, …) shows the
## same background instead of each re-adding its own TextureRect. Authored full-rect in
## [code]background.tscn[/code]; drop it in as a screen's first child, or instantiate with [method create]
## for code-built screens.

const SCENE_PATH := "res://ui/background/background.tscn"

## Instantiates the backdrop for code-built screens (e.g. the debug navigator). Fills its parent.
static func create() -> Background:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()
