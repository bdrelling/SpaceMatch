class_name PlinkoBall
extends RigidBody2D
## A piece of scrap dropped into the recycler. Carries the feeding scrap's ordered recycle outputs;
## the pocket it lands in picks which one is produced.

var outputs: Array[ItemStack] = []
var radius: float = 14.0
var color: Color = Color(0.78, 0.72, 0.6)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)

static func create(_outputs: Array[ItemStack], _radius: float = 14.0) -> PlinkoBall:
	var ball := PlinkoBall.new()
	ball.outputs = _outputs
	ball.radius = _radius
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var material := PhysicsMaterial.new()
	material.bounce = 0.2
	material.friction = 0.5
	ball.physics_material_override = material
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	ball.add_child(shape)
	return ball
