class_name PlinkoPeg
extends StaticBody2D
## A single plinko peg the scrap balls bounce off.

var radius: float = 9.0
var color: Color = Color(0.5, 0.5, 0.56)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)

static func create(_radius: float) -> PlinkoPeg:
	var peg := PlinkoPeg.new()
	peg.radius = _radius
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	peg.add_child(shape)
	return peg
