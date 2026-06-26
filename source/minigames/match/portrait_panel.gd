class_name PortraitPanel
extends Button
## A combatant portrait in the encounter HUD: a thumbnail of that ship's module grid, a name, and a
## strip of the four stat readouts (the four colored stat tiles — combat, propulsion, science, defense)
## along the bottom. Scrap, damage, and warp aren't ship stats, so they don't appear here. Tappable —
## the encounter decides what a tap opens (each combatant's module grid). Player on the left, opponent on
## the right, Puzzle-Quest style.
##
## The thumbnail (its hull and modules drawn in their grid colors) is the portrait art; until a grid is
## bound it falls back to a glyph. The host sets the grid, readouts, name, and health.

const _STYLE_NORMAL := preload("res://ui/styles/hud_placeholder.tres")
const _STYLE_ACTIVE := preload("res://ui/styles/hud_box_active.tres")
## Side length of each tiny tile in the readout strip.
const _TILE_PX: float = 44.0
## Height of the health bar under the name.
const _BAR_PX: float = 24.0
## Health bar fill — red, so damage reads at a glance.
const _HEALTH_FILL := Color(0.86, 0.27, 0.30)
## Shield fill — blue. Stacked into the same bar on top of the health: it picks up where the red leaves off
## and extends the bar past max health, so a shielded combatant reads as having a longer bar.
const _SHIELD_FILL := Color(0.35, 0.68, 0.92)
## The "EVADE" badge color — the yellow propulsion tile, matching the Evasive Maneuvers gem and its popup.
const _DODGE_COLOR := Color(0.95, 0.80, 0.25)
## The tile kinds shown in the readout strip — the four colored stat tiles, in [MatchTile] kind order.
## Kept in step with [MatchMinigame]'s readout order, which feeds [method set_readouts].
const _READOUT_KINDS: Array[int] = [0, 1, 2, 3]

## Big glyph shown above the name — a stand-in portrait.
@export var glyph: String = "▦"
## Name shown under the glyph.
@export var portrait_name: String = "Player"
## Current and maximum health, shown as the bar under the name.
@export var health: float = 100.0
@export var max_health: float = 100.0

var _value_labels: Array[Label] = []
var _health_fill: Panel
var _shield_fill: Panel
var _health_fill_style: StyleBoxFlat
var _shield_fill_style: StyleBoxFlat
var _health_label: Label
var _glyph_label: Label
var _grid_thumbnail: ModuleGridThumbnail
# Overlay badge shown while this combatant is armed to dodge the next attack (Evasive Maneuvers). Anchored
# over the portrait so toggling it never reflows the stat strip below.
var _dodge_indicator: Control

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("normal", _STYLE_NORMAL)
	add_theme_stylebox_override("focus", _STYLE_NORMAL)
	add_theme_stylebox_override("hover", _STYLE_ACTIVE)
	add_theme_stylebox_override("pressed", _STYLE_ACTIVE)
	_build()

# Builds the portrait's contents once: glyph, name, and a row of the four stat-tile readouts. The strip
# is data-driven (one cell per readout kind), so it's assembled in code rather than authored cell-by-cell.
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

	# One stacked bar: red health, then blue shield, then the empty remainder, laid out left to right in
	# that order. The bar's full width is max health (or current+shield when that's larger), so the shield
	# fills any missing-health gap first and only stretches the bar once it pushes past max health. The
	# dark panel is the track; the red and blue segments are children sized by anchor ratios in set_health.
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, _BAR_PX)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.clip_contents = true
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.13, 0.21, 0.6)
	bar_bg.set_corner_radius_all(int(_BAR_PX * 0.5))
	bar.add_theme_stylebox_override("panel", bar_bg)
	column.add_child(bar)

	var radius := int(_BAR_PX * 0.5)

	# Red health segment, anchored from the left; its right corners are squared off so the blue segment
	# butts cleanly against it (set_health rounds them back when there's no shield to follow).
	_health_fill = Panel.new()
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_fill.anchor_top = 0.0
	_health_fill.anchor_bottom = 1.0
	_health_fill_style = StyleBoxFlat.new()
	_health_fill_style.bg_color = _HEALTH_FILL
	_health_fill_style.set_corner_radius(CORNER_TOP_LEFT, radius)
	_health_fill_style.set_corner_radius(CORNER_BOTTOM_LEFT, radius)
	_health_fill.add_theme_stylebox_override("panel", _health_fill_style)
	bar.add_child(_health_fill)

	# Blue shield segment, anchored to start where the health ends; its right corners are rounded to cap
	# the filled run, its left corners squared to meet the health segment.
	_shield_fill = Panel.new()
	_shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_fill.anchor_top = 0.0
	_shield_fill.anchor_bottom = 1.0
	_shield_fill_style = StyleBoxFlat.new()
	_shield_fill_style.bg_color = _SHIELD_FILL
	_shield_fill_style.set_corner_radius(CORNER_TOP_RIGHT, radius)
	_shield_fill_style.set_corner_radius(CORNER_BOTTOM_RIGHT, radius)
	_shield_fill.add_theme_stylebox_override("panel", _shield_fill_style)
	bar.add_child(_shield_fill)

	# The health as "current of max" (with "(shield)" appended when shielded), centered over the bar.
	_health_label = Label.new()
	_health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_label.add_theme_font_size_override("font_size", 16)
	_health_label.add_theme_color_override("font_color", Color.WHITE)
	_health_label.add_theme_constant_override("outline_size", 4)
	_health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	bar.add_child(_health_label)

	set_health(health, max_health)

	var strip := HBoxContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 10)
	column.add_child(strip)

	_value_labels.clear()
	for kind: int in _READOUT_KINDS:
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

	_build_dodge_indicator()

# The "EVADE" badge: a yellow dot and label in a small chip, anchored top-center as an overlay so showing or
# hiding it never reflows the portrait. Hidden until [method set_dodge_active] turns it on.
func _build_dodge_indicator() -> void:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	badge.anchor_left = 0.5
	badge.anchor_right = 0.5
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Grow downward from the top edge — without this the chip expands upward off the portrait and is clipped.
	badge.grow_vertical = Control.GROW_DIRECTION_END
	badge.offset_top = 6.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.18, 0.9)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	style.set_border_width_all(2)
	style.border_color = _DODGE_COLOR
	badge.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	badge.add_child(row)

	var dot := Label.new()
	dot.text = "●"
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_color_override("font_color", _DODGE_COLOR)
	row.add_child(dot)

	var label := Label.new()
	label.text = "EVADE"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", _DODGE_COLOR)
	row.add_child(label)

	add_child(badge)
	_dodge_indicator = badge

## Sets the four stat readouts, in [constant _READOUT_KINDS] order (combat, propulsion, science, defense).
func set_readouts(values: PackedStringArray) -> void:
	for i: int in mini(values.size(), _value_labels.size()):
		_value_labels[i].text = values[i]

## Shows this combatant's module grid as the portrait thumbnail (modules in their grid colors). A null
## grid falls back to the glyph — e.g. before a session binds, or running this scene standalone.
func set_module_grid(grid: ModuleGridState) -> void:
	if _grid_thumbnail == null:
		return
	_grid_thumbnail.grid = grid
	var has_grid: bool = grid != null
	_grid_thumbnail.visible = has_grid
	if _glyph_label != null:
		_glyph_label.visible = not has_grid

## Shows or hides the "EVADE" badge — on while this combatant is armed to dodge the next attack.
func set_dodge_active(active: bool) -> void:
	if _dodge_indicator != null:
		_dodge_indicator.visible = active

## Frames this portrait as the active combatant (whose turn it is) by swapping in the active box.
func set_active(active: bool) -> void:
	var style: StyleBox = _STYLE_ACTIVE if active else _STYLE_NORMAL
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("focus", style)

## Sets the stacked health bar: red runs to [param current], blue picks up from there and runs the length
## of [param shield], and the empty remainder fills the rest. The bar spans whichever is larger — max
## health, or current health plus shield — so it only stretches past max health once the shield would
## carry health+shield beyond it. Max health itself never changes: the number reads "current of max", with
## " (shield)" appended when shielded.
func set_health(current: float, maximum: float, shield: float = 0.0) -> void:
	health = current
	max_health = maximum
	var shield_amount: float = maxf(shield, 0.0)
	# The bar spans whichever is larger: max health, or current health plus shield. So the shield only
	# stretches the bar once it would push health+shield past max health — below that it just fills the
	# missing-health gap, leaving no empty remainder.
	var total: float = maxf(maximum, current + shield_amount)
	var health_ratio: float = clampf(current / total, 0.0, 1.0) if total > 0.0 else 0.0
	var shield_end: float = clampf((current + shield_amount) / total, 0.0, 1.0) if total > 0.0 else 0.0
	if _health_fill != null:
		_health_fill.anchor_left = 0.0
		_health_fill.anchor_right = health_ratio
		# With a shield following, square off the right so the blue meets it flush; otherwise round it to
		# cap the filled run.
		var health_right: int = 0 if shield_amount > 0.0 else int(_BAR_PX * 0.5)
		_health_fill_style.set_corner_radius(CORNER_TOP_RIGHT, health_right)
		_health_fill_style.set_corner_radius(CORNER_BOTTOM_RIGHT, health_right)
	if _shield_fill != null:
		_shield_fill.visible = shield_amount > 0.0
		_shield_fill.anchor_left = health_ratio
		_shield_fill.anchor_right = shield_end
	if _health_label != null:
		var text: String = "%d of %d" % [roundi(current), roundi(maximum)]
		if shield_amount > 0.0:
			text += " (%d)" % roundi(shield_amount)
		_health_label.text = text
