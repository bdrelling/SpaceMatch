@tool
class_name Site
extends Node3D

@export var site_name: String = ""

@onready var bounds: Area3D = %Bounds

func _ready() -> void:
	if Engine.is_editor_hint():
		_recalculate_bounds()

func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED and Engine.is_editor_hint() and is_node_ready():
		_recalculate_bounds()

func _recalculate_bounds() -> void:
	var visual_instances: Array[VisualInstance3D] = []
	var transforms: Array[Transform3D] = []
	_collect_visual_instances(self, Transform3D.IDENTITY, visual_instances, transforms)
	if visual_instances.is_empty():
		return
	var combined: AABB = _transform_aabb(visual_instances[0].get_aabb(), transforms[0])
	for i: int in range(1, visual_instances.size()):
		combined = combined.merge(_transform_aabb(visual_instances[i].get_aabb(), transforms[i]))
	var shape_node: CollisionShape3D = bounds.get_child(0) as CollisionShape3D
	if shape_node == null:
		return
	var box: BoxShape3D = shape_node.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		shape_node.shape = box
	box.size = combined.size
	bounds.position = combined.get_center()

func _collect_visual_instances(node: Node, accumulated_transform: Transform3D, visual_instances: Array[VisualInstance3D], transforms: Array[Transform3D]) -> void:
	for child: Node in node.get_children():
		if child == bounds:
			continue
		if not child is Node3D:
			continue
		var child_transform: Transform3D = accumulated_transform * (child as Node3D).transform
		if child is VisualInstance3D:
			visual_instances.append(child as VisualInstance3D)
			transforms.append(child_transform)
		_collect_visual_instances(child, child_transform, visual_instances, transforms)

static func _transform_aabb(aabb: AABB, applied_transform: Transform3D) -> AABB:
	var corners: Array[Vector3] = []
	for i: int in 8:
		corners.append(applied_transform * (aabb.position + Vector3(
			aabb.size.x if (i & 1) else 0.0,
			aabb.size.y if (i & 2) else 0.0,
			aabb.size.z if (i & 4) else 0.0,
		)))
	var result: AABB = AABB(corners[0], Vector3.ZERO)
	for i: int in range(1, corners.size()):
		result = result.expand(corners[i])
	return result
