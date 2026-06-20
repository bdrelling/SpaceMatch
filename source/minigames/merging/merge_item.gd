class_name MergeItem
extends RigidBody2D
## A single piece. Carries its ladder [member tier]; when it touches another item on the same tier the
## board removes both and spawns one a tier higher. [member consumed] guards a pair from merging twice
## when both bodies report the same contact. The launcher's held item is the same body via [method hold]
## / [method release], so the preview is exactly the size and color of what falls.
##
## In PVP, [member owner_color] is the dropping player's color, drawn as a ring around the piece; a fully
## transparent color means unowned (the only state outside PVP) and draws no ring.

var tier: int = 0
var blueprint: MergeItemBlueprint
var consumed: bool = false
## The owning player's color in PVP, drawn as a ring; transparent (the non-PVP default) draws nothing.
var owner_color: Color = Color(0.0, 0.0, 0.0, 0.0)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if blueprint == null:
		return
	if blueprint.texture != null:
		var diameter := blueprint.radius * 2.0
		draw_texture_rect(blueprint.texture, Rect2(-blueprint.radius, -blueprint.radius, diameter, diameter), false)
	else:
		draw_circle(Vector2.ZERO, blueprint.radius, blueprint.color)
	if owner_color.a > 0.0:
		var ring_width: float = maxf(3.0, blueprint.radius * 0.16)
		draw_arc(Vector2.ZERO, blueprint.radius - ring_width * 0.5, 0.0, TAU, 48, owner_color, ring_width, true)

## [param gravity] scales the fall to the board size, so a bigger board (more pixels) falls
## proportionally faster and keeps the same feel.
static func create(item_tier: int, item_blueprint: MergeItemBlueprint, gravity: float = 1.0) -> MergeItem:
	var item := MergeItem.new()
	item.tier = item_tier
	item.blueprint = item_blueprint
	item.gravity_scale = gravity
	item.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	item.contact_monitor = true
	item.max_contacts_reported = 8
	var material := PhysicsMaterial.new()
	material.bounce = 0.05
	material.friction = 0.6
	item.physics_material_override = material
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = item_blueprint.radius
	shape.shape = circle
	item.add_child(shape)
	return item

## Pins the item still at the launcher with no collisions, so the host can slide it along the top rail.
func hold() -> void:
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	contact_monitor = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

## Hands the held item to physics with a downward kick. Resets [member Node2D.scale] so the body the
## simulation takes over is at its natural 1:1 size (the held counter-scale no longer applies).
func release(impulse_speed: float) -> void:
	scale = Vector2.ONE
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	contact_monitor = true
	freeze = false
	linear_velocity = Vector2(0.0, impulse_speed)
