@tool
class_name DebugRuleCard
extends MarginContainer
## A dashed-bordered, named card for one rule — its title (accent-coloured by the resource it acts on) over
## its configuration rows. The dashed border groups a rule's knobs so the whole rule reads as one unit, and
## independent rules each stand in their own box. Scene-backed by [code]debug_rule_card.tscn[/code] and
## [code]@tool[/code] so the border draws in the editor; built off-tree by [method create], add rows via
## [method add_row]. A debug widget — pairs with [DebugRow] inside the body.

const _BORDER_COLOR := Color(0.65, 0.70, 0.80, 0.16)
const _BORDER_WIDTH := 1.0
const _DASH := 16.0

const _SCENE := preload("res://scenes/debug_screen/widgets/debug_rule_card.tscn")

## Builds a card titled [param card_title], its title tinted [param accent].
static func create(card_title: String, accent: Color) -> DebugRuleCard:
	var card := _SCENE.instantiate() as DebugRuleCard
	var header: Label = card.get_node("%Header")
	header.text = card_title
	header.add_theme_color_override("font_color", accent)
	return card

func _ready() -> void:
	resized.connect(queue_redraw)

## Appends [param row] to the card body.
func add_row(row: Control) -> void:
	var body: VBoxContainer = %Body
	body.add_child(row)

func _draw() -> void:
	var rectangle := Rect2(Vector2.ZERO, size).grow(-4.0)
	var top_right := Vector2(rectangle.end.x, rectangle.position.y)
	var bottom_left := Vector2(rectangle.position.x, rectangle.end.y)
	draw_dashed_line(rectangle.position, top_right, _BORDER_COLOR, _BORDER_WIDTH, _DASH)
	draw_dashed_line(top_right, rectangle.end, _BORDER_COLOR, _BORDER_WIDTH, _DASH)
	draw_dashed_line(rectangle.end, bottom_left, _BORDER_COLOR, _BORDER_WIDTH, _DASH)
	draw_dashed_line(bottom_left, rectangle.position, _BORDER_COLOR, _BORDER_WIDTH, _DASH)
