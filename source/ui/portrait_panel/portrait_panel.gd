class_name PortraitPanel
extends Button
## A combatant portrait in the encounter HUD: a thumbnail of that starship's module grid, a name, and a
## strip of the four stat readouts (the four colored stat tiles — combat, propulsion, science, defense)
## along the bottom. Scrap, damage, and warp aren't starship stats, so they don't appear here. Tappable —
## the encounter decides what a tap opens (each combatant's module grid). Player on the left, opponent on
## the right, Puzzle-Quest style.
##
## The thumbnail (its hull and modules drawn in their grid colors) is the portrait art; until a grid is
## bound it falls back to a glyph. The host sets the grid, readouts, name, and health.
##
## The layout is authored in portrait_panel.tscn so it renders in the editor; this script only binds the
## live data (grid, readouts, name, health, dodge, active) onto the authored nodes.

const _STYLE_NORMAL := preload("res://ui/styles/hud_placeholder.tres")
const _STYLE_ACTIVE := preload("res://ui/styles/hud_box_active.tres")
## Height of the health bar under the name.
const _BAR_PX: float = 24.0

## Big glyph shown above the name — a stand-in portrait.
@export var glyph: String = "▦"
## Name shown under the glyph.
@export var portrait_name: String = "Player"
## Current and maximum health, shown as the bar under the name.
@export var health: float = 100.0
@export var max_health: float = 100.0

@onready var _glyph_label: Label = %Glyph
@onready var _grid_thumbnail: ModuleGridThumbnail = %GridThumbnail
@onready var _name_label: Label = %Name
@onready var _health_fill: Panel = %HealthFill
@onready var _shield_fill: Panel = %ShieldFill
@onready var _health_label: Label = %HealthLabel
# Overlay badge shown while this combatant is armed to dodge the next attack (Evasive Maneuvers). Anchored
# over the portrait so toggling it never reflows the stat strip below.
@onready var _dodge_indicator: Control = %DodgeBadge
@onready var _strip: HBoxContainer = %Strip

# The four stat-tile value labels, in readout order, collected from the authored strip cells.
var _value_labels: Array[Label] = []
# The styleboxes backing the health and shield fills — their corner radii are tuned live in set_health.
var _health_fill_style: StyleBoxFlat
var _shield_fill_style: StyleBoxFlat

func _ready() -> void:
	_health_fill_style = _health_fill.get_theme_stylebox("panel")
	_shield_fill_style = _shield_fill.get_theme_stylebox("panel")
	# Each strip cell is a VBoxContainer whose second child is its "Value" label.
	_value_labels.clear()
	for cell: Node in _strip.get_children():
		_value_labels.append(cell.get_node("Value"))
	_glyph_label.text = glyph
	_name_label.text = portrait_name
	set_health(health, max_health)

## Sets the four stat readouts, in [MatchTile] kind order (combat, propulsion, science, defense).
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
