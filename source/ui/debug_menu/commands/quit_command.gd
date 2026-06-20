class_name QuitCommand
extends ConsoleCommand

var _scene_tree: SceneTree

func _init(scene_tree: SceneTree) -> void:
	key = "quit"
	description = "quit game"
	allow_hint = true
	_scene_tree = scene_tree

func execute(args: PackedStringArray) -> void:
	_scene_tree.quit()
	super.execute(args)
