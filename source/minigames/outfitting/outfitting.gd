class_name OutfittingMinigame
extends Minigame
## Outfitting: shows the starship's module grid and the stat profile its modules sum to. Rearranging
## modules and buying new ones (from a shop) come later; for now this stage renders the loadout and
## lists its stats, each beside the match-3 tile it feeds (when it has one).

const _CELL_SIZE: float = 96.0
const _TILE_ICON_SIZE: float = 36.0

@onready var _canvas: BoardCanvas = %BoardCanvas
@onready var _stat_list: VBoxContainer = %StatList

var _grid_view: ModuleGridView
var _module_grid: ModuleGrid

func _ready() -> void:
	# Stand alone when this scene is run directly (dev preview): bind a fresh default game so the
	# loadout and its stats render without the game shell. As a mounted page, [MinigameScreen] binds
	# the real session instead, and this guard is false.
	if get_tree() != null and get_tree().current_scene == self:
		bind_session(GameSession.new_game())

## Mounts the player's module grid as the board and lists the stats its modules sum to. Called by
## [MinigameScreen] when the page mounts; the shell re-points this at another combatant's ship via
## [method show_starship] when a portrait drills in.
func bind_session(session: GameSession) -> void:
	if session == null or session.state == null:
		return
	_show_grid(session.state.starship.module_grid)

## Re-points the board at [param starship]'s module grid — called by the shell when a portrait drills
## in, so this one stage shows the player's loadout or an opponent's. Rebuilds the board and stats.
func show_starship(starship: StarshipState) -> void:
	if starship == null:
		return
	_show_grid(starship.module_grid)

# Rebuilds the board and stat list for [param module_grid], freeing the prior view first
# ([BoardCanvas.set_board] detaches the old board but doesn't free it, so re-pointing would otherwise
# leak views) and re-pointing the stats at the shown ship.
func _show_grid(module_grid: ModuleGrid) -> void:
	if module_grid == null:
		return
	if _module_grid != null and _module_grid.changed.is_connected(_rebuild_stats):
		_module_grid.changed.disconnect(_rebuild_stats)
	_module_grid = module_grid
	if _grid_view != null:
		_grid_view.queue_free()
	_grid_view = ModuleGridView.new()
	_grid_view.configure(_module_grid, _CELL_SIZE)
	_canvas.set_board(_grid_view, _grid_view.content_size())
	if not _module_grid.changed.is_connected(_rebuild_stats):
		_module_grid.changed.connect(_rebuild_stats)
	_rebuild_stats()

# The stat readout, in display order: the four tile-backed stats first (shown with their tile), then the
# tile-less stats. Each entry is [stat, label, tile kind] — tile kind -1 means the stat has no tile yet.
func _stat_rows() -> Array:
	return [
		[Stat.Type.POWER, "Power", 0],
		[Stat.Type.SPEED, "Speed", 1],
		[Stat.Type.SENSORS, "Sensors", 2],
		[Stat.Type.SHIELDS, "Shields", 3],
		[Stat.Type.LIFE_SUPPORT, "Life Support", -1],
		[Stat.Type.ARMOR, "Armor", -1],
		[Stat.Type.CARGO, "Cargo", -1],
		[Stat.Type.FUEL, "Fuel", -1],
	]

# Repopulates the stat list from the grid's current loadout: one row per stat, tile + name + value.
func _rebuild_stats() -> void:
	if _stat_list == null:
		return
	for child: Node in _stat_list.get_children():
		child.queue_free()
	var profile := _profile()
	for row: Array in _stat_rows():
		var stat: Stat.Type = row[0]
		var label: String = row[1]
		var tile_kind: int = row[2]
		_stat_list.add_child(_stat_row(label, tile_kind, profile.value(stat)))

# A stat profile summed from the loadout's modules (zeros when empty). Summed in the view — the grid is
# owned elsewhere; this just reads it (mirrors [MatchMinigame]).
func _profile() -> StatBlock:
	var total := StatBlock.new()
	if _module_grid == null:
		return total
	for placed: PlacedModule in _module_grid.placed_modules():
		if placed.module != null:
			total.add(placed.module.stats)
	return total

# One stat row: [tile][name ............ value]. The tile slot keeps its size even when the stat has no
# tile, so the name column stays aligned.
func _stat_row(label: String, tile_kind: int, value: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	line.add_child(_tile_icon(tile_kind))

	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	line.add_child(name_label)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 28)
	line.add_child(value_label)
	return line

# A fixed-size slot holding the stat's match-3 tile glyph, or an empty slot of the same size when the
# stat has no tile (kind < 0). Reuses [MatchTile]'s glyph art so the icon matches the board exactly.
func _tile_icon(kind: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(_TILE_ICON_SIZE, _TILE_ICON_SIZE)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if kind >= 0:
		var tile := MatchTile.new()
		tile.kind = kind
		tile.position = Vector2(_TILE_ICON_SIZE, _TILE_ICON_SIZE) * 0.5
		tile.scale = Vector2(_TILE_ICON_SIZE, _TILE_ICON_SIZE)
		slot.add_child(tile)
	return slot
