@tool
extends Node

@onready var terrain: Terrain3D = find_child("Terrain3D") as Terrain3D

func _ready() -> void:
	if not Engine.is_editor_hint() and has_node("UI"):
		var ui_node: Node = $UI
		ui_node.set("player", $Player)
	if not Engine.is_editor_hint() or not has_node("Environment"):
		return
	if not _sky3d_plugin_enabled():
		return
	$Environment.queue_free()
	_swap_environment_for_sky3d()

func _sky3d_plugin_enabled() -> bool:
	var editor: Object = Engine.get_singleton(&"EditorInterface")
	if editor == null:
		return false
	@warning_ignore("unsafe_method_access", "unsafe_cast")
	var enabled: bool = editor.call("is_plugin_enabled", "sky_3d") as bool
	return enabled

func _swap_environment_for_sky3d() -> void:
	var sky_script: GDScript = load("res://addons/sky_3d/src/Sky3D.gd") as GDScript
	if sky_script == null:
		return
	@warning_ignore("unsafe_cast")
	var sky3d: Node = sky_script.new() as Node
	if sky3d == null:
		return
	sky3d.name = "Sky3D"
	add_child(sky3d, true)
	move_child(sky3d, 1)
	sky3d.owner = self
	sky3d.set("current_time", 10)
	sky3d.set("enable_editor_time", false)
