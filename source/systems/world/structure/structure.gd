@tool
class_name Structure
extends Node3D
## Not marked @abstract: Godot's PackedScene.instantiate() rejects abstract scripts,
## which breaks inherited scenes that use this as their base.

signal interacted

@export_tool_button("Generate Collision") var generate_collision_button: Callable = _generate_collision

@onready var model: Node3D = %Model
@onready var collision_body: StaticBody3D = %CollisionBody
@onready var collision_shape: CollisionShape3D = %CollisionShape
@onready var interact_zone: InteractableZone = %InteractZone

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	interact_zone.player_entered.connect(_on_player_entered)
	interact_zone.player_exited.connect(_on_player_exited)

## Player-driven interaction. The player passes itself in (the zone is the proximity authority,
## so we don't cache it); base does nothing but announce. Subclasses override to act on it.
func interact(_player: Player) -> void:
	if Engine.is_editor_hint():
		return
	interacted.emit()

func _generate_collision() -> void:
	var merged := AABB()
	var initialized := false
	for mesh in _collect_meshes(model):
		var mesh_transform := global_transform.affine_inverse() * mesh.global_transform
		var local_aabb := mesh_transform * mesh.get_aabb()
		if not initialized:
			merged = local_aabb
			initialized = true
		else:
			merged = merged.merge(local_aabb)
	if not initialized:
		return
	var box := BoxShape3D.new()
	box.size = merged.size
	collision_shape.shape = box
	collision_shape.position = merged.get_center()

func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		result.append_array(_collect_meshes(child))
	return result

func _on_player_entered(player: Player) -> void:
	player.add_structure_in_range(self)

func _on_player_exited(player: Player) -> void:
	player.remove_structure_in_range(self)
