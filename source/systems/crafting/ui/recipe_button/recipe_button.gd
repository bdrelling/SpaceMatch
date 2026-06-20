class_name RecipeButton
extends Button
## A recipe entry button whose face doubles as a progress bar while its recipe crafts.

const SCENE_PATH := "res://systems/crafting/ui/recipe_button/recipe_button.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## Craft progress shown across the face, 0..1; the fill hides at 0.
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_apply_progress()

@onready var _fill: ProgressBar = %Fill

func _ready() -> void:
	_apply_progress()

func _apply_progress() -> void:
	if _fill == null:
		return
	_fill.value = progress
	_fill.visible = progress > 0.0

static func create(title: String = "") -> RecipeButton:
	var button: RecipeButton = SCENE.instantiate()
	button.text = title
	return button
