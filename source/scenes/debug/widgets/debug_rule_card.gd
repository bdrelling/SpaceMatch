class_name DebugRuleCard
extends MarginContainer
## A dashed-bordered, named card for one rule — its title (accent-coloured by the resource it acts on) over
## its configuration rows. The dashed border groups a rule's knobs so the whole rule reads as one unit, and
## independent rules each stand in their own box. Built off-tree by [method create]; add rows via
## [method add_row]. A debug widget — pairs with [DebugRow] inside the body.

const _BORDER_COLOR := Color(0.65, 0.70, 0.80, 0.16)
const _BORDER_WIDTH := 1.0
const _TITLE_FONT := 34
const _PAD := 20
const _DASH := 16.0

var _body: VBoxContainer

## Builds a card titled [param card_title], its title tinted [param accent].
static func create(card_title: String, accent: Color) -> DebugRuleCard:
	var card := DebugRuleCard.new()
	card._build(card_title, accent)
	return card

func _build(card_title: String, accent: Color) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("margin_left", _PAD)
	add_theme_constant_override("margin_right", _PAD)
	add_theme_constant_override("margin_top", _PAD)
	add_theme_constant_override("margin_bottom", _PAD)
	resized.connect(queue_redraw)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := Label.new()
	header.text = card_title
	header.add_theme_font_size_override("font_size", _TITLE_FONT)
	header.add_theme_color_override("font_color", accent)
	column.add_child(header)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	column.add_child(_body)

## Appends [param row] to the card body.
func add_row(row: Control) -> void:
	_body.add_child(row)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-4.0)
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	draw_dashed_line(rect.position, top_right, _BORDER_COLOR, _BORDER_WIDTH, _DASH)
	draw_dashed_line(top_right, rect.end, _BORDER_COLOR, _BORDER_WIDTH, _DASH)
	draw_dashed_line(rect.end, bottom_left, _BORDER_COLOR, _BORDER_WIDTH, _DASH)
	draw_dashed_line(bottom_left, rect.position, _BORDER_COLOR, _BORDER_WIDTH, _DASH)
