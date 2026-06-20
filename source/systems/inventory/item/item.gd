class_name Item
extends RigidBody3D
## A physical, collectible item in the world.

#region Types

## Broad role of an item, authored on its [ItemBlueprint]. Drives loot weighting, which recipes
## consume it, and which station accepts it. MATERIAL is reserved for a future raw-material tier and
## has no items yet.
enum Category { SCRAP, MATERIAL, COMPONENT, MODULE }

## Per-instance markers distinguishing variants of one item id. A tagged item shares its
## untagged sibling's blueprint but stacks separately (see [ItemVariantId]).
enum Tag { DAMAGED }

#endregion

#region Constants

const SCENE_PATH := "res://systems/inventory/item/item.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## Duration of the fly-into-inventory "zoop" on collection. Matches the project's
## default animation duration (see OverlayPanel, BoardObject).
const COLLECT_DURATION: float = 0.35
## Height above the target's origin the item homes toward (roughly torso height).
const _COLLECT_TARGET_HEIGHT: float = 0.9
## Mesh scale the item shrinks to as it lands, just before it frees itself.
const _COLLECT_END_SCALE: Vector3 = Vector3(0.1, 0.1, 0.1)

#endregion

#region Signals

## Emitted when a launched item settles and becomes collectable — it hit the ground or a
## structure, or its safety timeout elapsed. Carries the item so an [ItemCollector] in whose
## field it landed can highlight it.
signal became_collectable(item: Item)

#endregion

#region Properties

@export var blueprint: ItemBlueprint

@export var id: int = -1
@export var item_name: String

## This item's role, copied from its blueprint. See [enum Category].
var category: Category = Category.SCRAP

## Instance tags marking variants (e.g. [constant Tag.DAMAGED]), stamped at runtime via
## [method add_tag].
var tags: Array[Tag] = []

## True when this item carries [constant Tag.DAMAGED].
var is_damaged: bool:
	get:
		return has_tag(Tag.DAMAGED)

## The variant this item currently is — id plus instance tags. Computed fresh because tags mutate.
var variant_id: ItemVariantId:
	get:
		return ItemVariantId.new(id, tags)

## Name including variant tags (see [method tagged_name]).
var display_name: String:
	get:
		return tagged_name(item_name, tags)

## Max time a launched item stays non-collectable before it's force-enabled — a safety net for
## when it never reports a clean landing (wedged against geometry, came to rest mid-air, etc.).
@export var settle_timeout: float = 1.5

@export_group("Nodes")
@export var world_mesh: MeshInstance3D
@export var collision_shape: CollisionShape3D

## Whether the collection highlight is shown. Driven by [ItemCollector] as the
## item enters or leaves a collector's range.
var highlighted: bool = false:
	set(value):
		highlighted = value
		if world_mesh:
			# Through the focus arbiter, not SilhouetteHighlighter directly, so the item only
			# shows when it's the single focus (and never steals focus from what you're at).
			if value:
				InteractionFocus.enter(world_mesh, self)
			else:
				InteractionFocus.exit(world_mesh)

## Whether the item can be collected right now. Launched items start false until they land
## (or [member settle_timeout] fires); items placed directly in the world start collectable.
var collectable: bool = true

var _collecting: bool = false
var _collect_target: Node3D
var _collect_start: Vector3

#endregion

#region Lifecycle

func _ready() -> void:
	# Items dropped straight into a scene carry their blueprint via the inspector;
	# those built through create() already applied it before entering the tree.
	if blueprint:
		apply_blueprint(blueprint)

#endregion

#region Appearance

func _apply_appearance() -> void:
	if not world_mesh:
		return

	if blueprint.world_mesh:
		world_mesh.mesh = blueprint.world_mesh
		# Match the collider to the mesh so a cube/cylinder doesn't roll like the default ball.
		if collision_shape:
			collision_shape.shape = blueprint.world_mesh.create_convex_shape()

	var material := StandardMaterial3D.new()
	material.albedo_color = blueprint.color
	world_mesh.material_override = material

#endregion

#region Collection

## Flies the item into [param target], shrinking as it lands, then frees itself.
## The inventory add has already happened by the time this runs — this is purely the
## "zoop" so a collected item doesn't just wink out. Physics and detection are killed
## up front so it can't fall, collide, or be re-detected mid-flight.
func collect_into(target: Node3D, duration: float = COLLECT_DURATION) -> void:
	if _collecting:
		return
	_collecting = true
	_collect_target = target
	_collect_start = global_position
	freeze = true
	collision_layer = 0
	collision_mask = 0
	highlighted = false

	var tween: Tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_collect_step, 0.0, 1.0, duration)
	tween.tween_callback(queue_free)

func _collect_step(t: float) -> void:
	var destination: Vector3 = _collect_start
	if is_instance_valid(_collect_target):
		destination = _collect_target.global_position + Vector3(0.0, _COLLECT_TARGET_HEIGHT, 0.0)
	global_position = _collect_start.lerp(destination, t)
	if world_mesh:
		world_mesh.scale = Vector3.ONE.lerp(_COLLECT_END_SCALE, t)

#endregion

#region Settling

## Throws the item with [param impulse] (plus optional [param spin]) and holds it
## non-collectable until it lands or [member settle_timeout] elapses — so a freshly ejected
## item can't be grabbed mid-air while the player mashes interact. Use this for thrown items
## instead of a bare [method RigidBody3D.apply_central_impulse].
func launch(impulse: Vector3, spin: Vector3 = Vector3.ZERO) -> void:
	collectable = false
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 1)
	if not body_entered.is_connected(_on_launch_contact):
		body_entered.connect(_on_launch_contact)
	apply_central_impulse(impulse)
	if spin != Vector3.ZERO:
		apply_torque_impulse(spin)
	get_tree().create_timer(settle_timeout).timeout.connect(_settle)

# Items never collide with each other (PROPS isn't in their mask), so any reported contact is
# the ground or a structure — the item has landed.
func _on_launch_contact(_body: Node) -> void:
	_settle()

func _settle() -> void:
	if collectable:
		return
	collectable = true
	# _settle can run inside the body_entered callback, where set_contact_monitor is
	# locked — defer the write so Godot applies it after the contact callback unwinds.
	set_deferred("contact_monitor", false)
	if body_entered.is_connected(_on_launch_contact):
		body_entered.disconnect(_on_launch_contact)
	became_collectable.emit(self)

#endregion

#region Tags

## Adds [param tag] to this item if it isn't already present. Idempotent.
func add_tag(tag: Tag) -> void:
	if not tags.has(tag):
		tags.append(tag)

## Whether this item carries [param tag].
func has_tag(tag: Tag) -> bool:
	return tags.has(tag)

## Composes a display name for [param base_name] carrying [param _tags] — each tag's name,
## capitalized, prefixes the base.
static func tagged_name(base_name: String, _tags: Array[Tag]) -> String:
	var result: String = base_name
	for tag: Tag in _tags:
		var tag_name: String = Tag.keys()[tag]
		result = "%s %s" % [tag_name.capitalize(), result]
	return result

#endregion

#region Blueprinting

func apply_blueprint(_blueprint: ItemBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return

	blueprint = _blueprint
	id = _blueprint.id
	item_name = _blueprint.name
	category = _blueprint.category
	_apply_appearance()

static func create(_blueprint: ItemBlueprint) -> Item:
	if not _blueprint:
		Log.error("Blueprint required to create Item")
		return null

	var item: Item = SCENE.instantiate()
	item.apply_blueprint(_blueprint)
	return item

#endregion
