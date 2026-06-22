class_name PortraitPanel
extends Button
## A combatant portrait in the encounter HUD: a big glyph, a name, and a strip of six stat readouts
## (one per tile kind) along the bottom. Tappable — the encounter decides what a tap opens (the player's
## outfitting, the opponent's intel). Player on the left, opponent on the right, Puzzle-Quest style.
##
## A placeholder until real portrait art lands; the glyph and readouts are set by the host.

const _STYLE_NORMAL := preload("res://ui/styles/hud_placeholder.tres")
const _STYLE_ACTIVE := preload("res://ui/styles/hud_box_active.tres")
## Side length of each tiny tile in the readout strip.
const _TILE_PX: float = 44.0

## Big glyph shown above the name — a stand-in portrait.
@export var glyph: String = "▦"
## Name shown under the glyph.
@export var portrait_name: String = "Player"

var _value_labels: Array[Label] = []

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("normal", _STYLE_NORMAL)
	add_theme_stylebox_override("focus", _STYLE_NORMAL)
	add_theme_stylebox_override("hover", _STYLE_ACTIVE)
	add_theme_stylebox_override("pressed", _STYLE_ACTIVE)
	_build()

# Builds the portrait's contents once: glyph, name, and a row of six tile readouts. The strip is
# data-driven (one cell per tile kind), so it's assembled in code rather than authored cell-by-cell.
func _build() -> void:
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 16)
	add_child(margins)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	margins.add_child(column)

	var icon := Label.new()
	icon.text = glyph
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.add_theme_font_size_override("font_size", 72)
	icon.add_theme_color_override("font_color", Color(0.78, 0.82, 0.95))
	column.add_child(icon)

	var label := Label.new()
	label.text = portrait_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.85))
	column.add_child(label)

	var strip := HBoxContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 10)
	column.add_child(strip)

	_value_labels.clear()
	for kind: int in MatchTile.KIND_COUNT:
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override("separation", 2)
		strip.add_child(cell)

		var tile := TileIcon.new()
		tile.kind = kind
		tile.custom_minimum_size = Vector2(_TILE_PX, _TILE_PX)
		cell.add_child(tile)

		var value := Label.new()
		value.text = "—"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 22)
		value.add_theme_color_override("font_color", Color(0.78, 0.82, 0.95))
		cell.add_child(value)
		_value_labels.append(value)

## Sets the six readouts, tile-kind ordered (combat, propulsion, science, defense, scrap, anomaly).
func set_readouts(values: PackedStringArray) -> void:
	for i: int in mini(values.size(), _value_labels.size()):
		_value_labels[i].text = values[i]

## Frames this portrait as the active combatant (whose turn it is) by swapping in the active box.
func set_active(active: bool) -> void:
	var style: StyleBox = _STYLE_ACTIVE if active else _STYLE_NORMAL
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("focus", style)
