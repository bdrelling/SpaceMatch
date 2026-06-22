class_name PortraitPanel
extends Button
## A combatant portrait in the encounter HUD: a thumbnail of that ship's module grid, a name, and a
## strip of six stat readouts (one per tile kind) along the bottom. Tappable — the encounter decides
## what a tap opens (each combatant's module grid). Player on the left, opponent on the right,
## Puzzle-Quest style.
##
## The thumbnail (its hull and modules drawn in their grid colors) is the portrait art; until a grid is
## bound it falls back to a glyph. The host sets the grid, readouts, name, and health.

const _STYLE_NORMAL := preload("res://ui/styles/hud_placeholder.tres")
const _STYLE_ACTIVE := preload("res://ui/styles/hud_box_active.tres")
const _STYLE_BAR_FILL := preload("res://ui/styles/stat_bar.tres")
## Side length of each tiny tile in the readout strip.
const _TILE_PX: float = 44.0
## Height of the health bar under the name.
const _BAR_PX: float = 24.0

## Big glyph shown above the name — a stand-in portrait.
@export var glyph: String = "▦"
## Name shown under the glyph.
@export var portrait_name: String = "Player"
## Current and maximum health, shown as the bar under the name.
@export var health: float = 100.0
@export var max_health: float = 100.0

var _value_labels: Array[Label] = []
var _health_bar: ProgressBar
var _glyph_label: Label
var _grid_thumbnail: ModuleGridThumbnail

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

	# The portrait art: the ship's module grid, drawn in each module's grid color. The glyph stacks in
	# the same slot as a fallback, shown only until a grid is bound (e.g. running this scene standalone).
	_glyph_label = Label.new()
	_glyph_label.text = glyph
	_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph_label.add_theme_font_size_override("font_size", 72)
	_glyph_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.95))
	column.add_child(_glyph_label)

	_grid_thumbnail = ModuleGridThumbnail.new()
	_grid_thumbnail.custom_minimum_size = Vector2(0, 200)
	_grid_thumbnail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_thumbnail.visible = false
	column.add_child(_grid_thumbnail)

	var label := Label.new()
	label.text = portrait_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.85))
	column.add_child(label)

	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(0, _BAR_PX)
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.min_value = 0.0
	_health_bar.max_value = max_health
	_health_bar.value = health
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.13, 0.21, 0.6)
	bar_bg.set_corner_radius_all(int(_BAR_PX * 0.5))
	_health_bar.add_theme_stylebox_override("background", bar_bg)
	_health_bar.add_theme_stylebox_override("fill", _STYLE_BAR_FILL)
	column.add_child(_health_bar)

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

## Shows this combatant's module grid as the portrait thumbnail (modules in their grid colors). A null
## grid falls back to the glyph — e.g. before a session binds, or running this scene standalone.
func set_module_grid(grid: ModuleGrid) -> void:
	if _grid_thumbnail == null:
		return
	_grid_thumbnail.grid = grid
	var has_grid: bool = grid != null
	_grid_thumbnail.visible = has_grid
	if _glyph_label != null:
		_glyph_label.visible = not has_grid

## Frames this portrait as the active combatant (whose turn it is) by swapping in the active box.
func set_active(active: bool) -> void:
	var style: StyleBox = _STYLE_ACTIVE if active else _STYLE_NORMAL
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("focus", style)

## Sets the health bar's current and maximum value.
func set_health(current: float, maximum: float) -> void:
	health = current
	max_health = maximum
	if _health_bar != null:
		_health_bar.max_value = maximum
		_health_bar.value = current
