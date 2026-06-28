class_name FloatingText
extends Node2D
## A short-lived combat popup: a line of text that drifts upward and fades, then frees itself. Spawned at
## a board position to show what a match yielded ("+3 Defense") or the damage an attack dealt ("-5"). Made
## in code via [method FloatingText.new], dropped onto an overlay, and handed its text through [method setup].

## How far (px, design space) the text rises over its life.
const _RISE_PX: float = 64.0
## Seconds from spawn to fully faded and freed.
const _LIFETIME: float = 0.9
const _FONT_SIZE: int = 30

var _label: Label

func _init() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", _FONT_SIZE)
	# A dark outline so the text stays legible over any tile color it floats above.
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_label)

## Sets the popup's text and color, centers it on this node's origin, and starts the rise-and-fade. Call
## once, after the node is in the tree and positioned.
func setup(text: String, color: Color) -> void:
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	# Center the label on the origin so it rises about the spawn point rather than off to one side.
	_label.position = -_label.get_minimum_size() * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - _RISE_PX, _LIFETIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, _LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
