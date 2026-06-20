class_name CompassRose
extends Control
## A circular compass — a thick ringed bezel with the four cardinal directions arranged
## around it. The bezel is drawn to fill the control; the cardinal labels orbit inside it
## and track the player's camera heading, so north always points to world north.
##
## Shared by the HUD [Minimap] (small) and the full-screen [Map] (large): it derives ring
## thickness and label size from its own size, so it reads correctly at any scale.

const _PALETTE := preload("res://systems/design/rustyard.tres")

## Cardinal directions in screen space, paired index-for-index with [member _labels].
const _DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

@export var player: Player

@onready var _rose: Control = %Rose
@onready var _labels: Array[Label] = [%NorthLabel, %EastLabel, %SouthLabel, %WestLabel]

func _ready() -> void:
	resized.connect(_relayout)
	_relayout()

## Sets the [Player] whose camera heading the rose tracks. Pass null to stop tracking.
func bind_player(value: Player) -> void:
	player = value

func _process(_delta: float) -> void:
	if player == null:
		return
	_rose.rotation = -player.get_camera_facing_yaw()

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	var border := _border_width()
	if radius <= border:
		return
	# Filled disc, then a thick ring riding its outer edge.
	draw_circle(center, radius - border, _PALETTE.hud_minimap_background)
	draw_arc(center, radius - border / 2.0, 0.0, TAU, 64, _PALETTE.hud_minimap_border, border, true)

func _relayout() -> void:
	_rose.pivot_offset = size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	var font_size := clampi(roundi(radius * 0.22), 9, 96)
	var inset := _border_width() + radius * 0.06
	for i in _labels.size():
		var label := _labels[i]
		label.add_theme_font_size_override("font_size", font_size)
		label.reset_size()
		var orbit := radius - inset - label.size.y / 2.0
		var point := size / 2.0 + _DIRECTIONS[i] * orbit
		label.position = point - label.size / 2.0
	queue_redraw()

func _border_width() -> float:
	return maxf(2.0, minf(size.x, size.y) * 0.05)
