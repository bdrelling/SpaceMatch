class_name MergingMinigame
extends Minigame
## Suika-style merge stage: tap the bin to drop an item where you aimed, and equal tiers fuse upward.
## The ladder is data — assign [member tiers] to swap in real item sprites and sizes; left empty it
## falls back to ten hue-ramped circles. Score shows in the shell's inventory strip, the run state as
## [member status_text].

const _SCORE_COLOR := Color(0.85, 0.78, 0.45)

## The merge ladder, low tier to high. Empty builds a default ladder from the knobs below.
@export var tiers: Array[MergeItemBlueprint] = []
## Radius of the base (smallest) item, in the 720×1040 board space. Small so the cherry reads tiny.
@export var base_radius: float = 18.0
## The largest item's diameter as a fraction of the bin width; the rest scale up to it.
@export var max_width_fraction: float = 0.5
## Bends the size spacing between min and max: 1.0 = constant ratio, below 1 spreads the small tiers
## apart (easier to tell the drops apart, like Suika), above 1 clusters them tiny then ramps.
@export var size_curve: float = 0.78
## How many tiers the default ladder has — 11, to match Suika.
@export var tier_count: int = 11
## Highest tier the dropper spawns (the smallest few); the bigger tiers are earned by merging.
@export var max_drop_tier: int = 4
## Non-zero makes the drop sequence reproducible (used by tests).
@export var board_seed: int = 0

@onready var _canvas: BoardCanvas = %BoardCanvas

var _board: MergeBoard
var _gestures: GestureRecognizer
var _aim_global: Vector2 = Vector2.ZERO
var _game_over_banner: Label
# Player-versus-player mode: drops alternate red/blue and merges take the dropping player's color.
var _pvp: bool = false

func _ready() -> void:
	# Mount the board unscaled (size it to the canvas in _rebuild), so the bin fills the screen and the
	# physics items render 1:1 with it — that keeps each fruit a fixed fraction of the bin width.
	_canvas.padding = 0.0

	# Route board taps through the recognizer like the other minigames, so a tap reads as a tap (not the
	# start of a page swipe) and off-board touches still reach the arcade pager.
	_gestures = GestureRecognizer.new()
	_gestures.cell_resolver = _resolve_cell
	_gestures.tap.connect(_on_tap)
	_gestures.set_process_unhandled_input(false)
	add_child(_gestures)
	_canvas.input_handler = _gestures.handle_event

	_build_game_over_banner()
	_canvas.resized.connect(_rebuild)
	_rebuild()
	_update_status()

# (Re)builds the board sized to the canvas. Runs once the canvas has a size and again on any resize.
func _rebuild() -> void:
	var board_size := _canvas.size
	if board_size.x < 1.0 or board_size.y < 1.0:
		return
	if _board != null and _board.size == board_size:
		return
	var unit := board_size.x / MergeBoard.REFERENCE_SIZE.x
	var max_radius := max_width_fraction * 0.5 * board_size.x
	var ladder: Array[MergeItemBlueprint] = tiers if not tiers.is_empty() else MergeItemBlueprint.default_ladder(tier_count, base_radius * unit, max_radius, size_curve)
	var previous := _board
	_board = MergeBoard.new()
	_board.pvp = _pvp
	_board.merged.connect(_on_merged)
	_board.game_over.connect(_on_game_over)
	_board.build(ladder, board_seed, max_drop_tier, board_size)
	_canvas.set_board(_board, board_size)
	if previous != null:
		previous.queue_free()
	if _game_over_banner != null:
		_game_over_banner.visible = false
	_update_status()

# A centred "Stacked out" banner over the board, hidden until the run ends — the on-board cue the
# shell's status line alone didn't make obvious.
func _build_game_over_banner() -> void:
	_game_over_banner = Label.new()
	_game_over_banner.text = "STACKED OUT\nTap Reset"
	_game_over_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_banner.add_theme_font_size_override("font_size", 72)
	_game_over_banner.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	_game_over_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	_game_over_banner.add_theme_constant_override("outline_size", 12)
	_game_over_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_banner.visible = false
	add_child(_game_over_banner)

# A point over the bin aims there (live feedback) and counts as a tap; off the bin returns NO_CELL so
# the recognizer ignores it and the pager can still swipe in the margins.
func _resolve_cell(screen_position: Vector2) -> Vector2i:
	if _board == null or not _board.contains_global(screen_position):
		return GestureRecognizer.NO_CELL
	_aim_global = screen_position
	_board.aim_to_global(screen_position)
	return Vector2i.ZERO

func _on_tap(_cell: Vector2i) -> void:
	if _board == null:
		return
	_board.aim_to_global(_aim_global)
	_board.drop()
	_update_status()

func _on_merged(_tier: int, _points: int) -> void:
	_update_status()

func _on_game_over() -> void:
	if _game_over_banner != null:
		_game_over_banner.visible = true
	_update_status()

func actions() -> Array[MinigameAction]:
	var pvp_label := "PVP: On" if _pvp else "PVP: Off"
	var list: Array[MinigameAction] = [
		MinigameAction.new("Reset", _on_reset),
		MinigameAction.new(pvp_label, _on_pvp_pressed),
	]
	return list

func _on_reset() -> void:
	if _game_over_banner != null:
		_game_over_banner.visible = false
	if _board != null:
		_board.reset()
	_update_status()

# Flips PVP and starts a fresh bin in the new mode, relabelling the toggle.
func _on_pvp_pressed() -> void:
	_pvp = not _pvp
	if _game_over_banner != null:
		_game_over_banner.visible = false
	if _board != null:
		_board.pvp = _pvp
		_board.reset()
	actions_changed.emit()
	_update_status()

func inventory_chips() -> Array[InventoryChip]:
	var score := _board.score if _board != null else 0
	var chips: Array[InventoryChip] = [InventoryChip.new("Score", score, _SCORE_COLOR)]
	return chips

func _update_status() -> void:
	if _board == null:
		return
	if not _board.alive:
		status_text = "Stacked out at %d — tap Reset for a fresh bin" % _board.score
	elif _pvp:
		var who := "Blue" if _board.current_player() == MergeBoard.PLAYER_BLUE else "Red"
		status_text = "PVP — %s to drop; merge to claim items in your color" % who
	else:
		status_text = "Score %d — tap the bin to drop, merge equal items to climb" % _board.score
	inventory_changed.emit()
