class_name PlinkoSlot
extends Area2D
## One of the three slots at the bottom of the board. A ball landing here pays the slot's component
## and, unless the player has locked it, changes the slot's type. The player locks a slot to hold its
## type while aiming drops into the others to match it. Detects the ball and reports the catch; the
## board reads [member output_index] to pay out and to check for an alignment.

signal ball_landed(slot: PlinkoSlot, ball: PlinkoBall)

## The matchable component types, as recycle-output indices: wire, tube, panel. The module is never a
## slot type — it is the reward for matching three of these.
const _TYPE_COUNT := 3

var width: float = 200.0
var height: float = 180.0
var samples: Array[ItemStack] = []
var output_index: int = 0
var locked: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var ball := body as PlinkoBall
	if ball == null:
		return
	ball_landed.emit(self, ball)

## Changes the slot to a random component type — what an unlocked slot does when it catches a ball.
func change_type() -> void:
	output_index = randi() % _TYPE_COUNT
	queue_redraw()

func toggle_lock() -> void:
	locked = not locked
	queue_redraw()

func unlock() -> void:
	locked = false
	queue_redraw()

## Whether [param point] (in board-local space) is inside this slot — for hit-testing a lock tap.
func contains_point(point: Vector2) -> bool:
	return absf(point.x - position.x) <= width * 0.5 and absf(point.y - position.y) <= height * 0.5

func _draw() -> void:
	var rect := Rect2(-width * 0.5, -height * 0.5, width, height)
	var tint := _tint()
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.45), true)
	var border_color := Color(1.0, 0.9, 0.5) if locked else tint
	var border_width := 5.0 if locked else 1.5
	draw_rect(rect, border_color, false, border_width)

	var label := _label()
	var font := ThemeDB.fallback_font
	if label != "" and font != null:
		var font_size := 34
		draw_string(font, Vector2(-width * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color.WHITE)
		if locked:
			draw_string(font, Vector2(-width * 0.5, height * 0.5 - 16.0), "LOCKED", HORIZONTAL_ALIGNMENT_CENTER, width, 20, Color(1.0, 0.9, 0.5))

func _tint() -> Color:
	if output_index < samples.size() and samples[output_index] != null and samples[output_index].item_blueprint != null:
		return samples[output_index].item_blueprint.color
	return Color(0.8, 0.8, 0.85)

func _label() -> String:
	if output_index < samples.size() and samples[output_index] != null and samples[output_index].item_blueprint != null:
		return samples[output_index].item_blueprint.name
	return ""

static func create(_width: float, _height: float, _samples: Array[ItemStack]) -> PlinkoSlot:
	var slot := PlinkoSlot.new()
	slot.width = _width
	slot.height = _height
	slot.samples = _samples
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(_width, _height)
	shape.shape = rectangle
	slot.add_child(shape)
	return slot
