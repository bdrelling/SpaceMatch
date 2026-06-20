class_name ItemCollector
extends Area3D
## A spherical field that highlights nearby [Item]s and serves up the closest one on
## request. The owning entity (e.g. [Player]) drives collection — on its interact press
## it calls [method get_nearest] and routes the item into an [Inventory], then
## [method forget]s it.

#region Constants

const SCENE_PATH := "res://systems/inventory/item_collector/item_collector.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

#endregion

#region Signals

signal item_entered_range(item: Item)
signal item_exited_range(item: Item)

#endregion

#region Properties

## Radius of the spherical collection field, in metres. Applied to [member collision_shape]
## on ready, so tweaking it in the inspector resizes the field.
@export var collection_radius: float = 2.0

@export_group("Nodes")
@export var collision_shape: CollisionShape3D

var _items_in_range: Array[Item] = []

#endregion

#region Lifecycle

func _ready() -> void:
	# Detect items only — never report them as an obstacle.
	collision_layer = 0
	collision_mask = CollisionLayer.PROPS
	_apply_radius()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

#endregion

#region Interface

## The closest in-range item, or null. Does not remove or free it — the caller decides
## whether it fits in inventory before claiming it.
func get_nearest() -> Item:
	var nearest: Item = null
	var nearest_distance_squared: float = INF
	for item: Item in _items_in_range:
		if not is_instance_valid(item) or not item.collectable:
			continue
		var distance_squared: float = global_position.distance_squared_to(item.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = item
			nearest_distance_squared = distance_squared
	return nearest

## Stops tracking [param item] and clears its highlight — call once it's been collected
## (the node is usually freed immediately after, so body_exited won't fire).
func forget(item: Item) -> void:
	_items_in_range.erase(item)
	if is_instance_valid(item):
		_disconnect_settle(item)
		item.highlighted = false

#endregion

#region Detection

func _apply_radius() -> void:
	if not collision_shape:
		return
	var sphere: SphereShape3D = collision_shape.shape as SphereShape3D
	if sphere:
		# Own a copy so resizing one collector doesn't mutate the shared scene shape.
		sphere = sphere.duplicate()
		sphere.radius = collection_radius
		collision_shape.shape = sphere

func _on_body_entered(body: Node3D) -> void:
	var item: Item = body as Item
	if not item or _items_in_range.has(item):
		return
	_items_in_range.append(item)
	# A launched item that hasn't landed yet shouldn't look grabbable — wait for it to settle.
	if item.collectable:
		item.highlighted = true
	else:
		item.became_collectable.connect(_on_item_settled)
	item_entered_range.emit(item)

func _on_body_exited(body: Node3D) -> void:
	var item: Item = body as Item
	if not item:
		return
	_items_in_range.erase(item)
	if is_instance_valid(item):
		_disconnect_settle(item)
		item.highlighted = false
	item_exited_range.emit(item)

# A launched item settled while still in our field — highlight it now that it's grabbable.
func _on_item_settled(item: Item) -> void:
	if is_instance_valid(item) and _items_in_range.has(item):
		item.highlighted = true

func _disconnect_settle(item: Item) -> void:
	if item.became_collectable.is_connected(_on_item_settled):
		item.became_collectable.disconnect(_on_item_settled)

#endregion
