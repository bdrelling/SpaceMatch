class_name LoadoutEditor
extends Control
## The loadout editor — the feature [LoadoutScreen] hosts: a starship's module grid plus the stat profile
## its modules sum to. It runs in three [enum Mode]s the host sets per context — [constant Mode.READ_ONLY]
## when inspecting a starship, [constant Mode.EDIT] when modifying one (e.g. a shop), and [constant
## Mode.SELECT] when loading out a starship at game start. Tapping a module focuses it (name + per-stat
## contribution) in any mode; dragging to rearrange is allowed only in the editable modes.

#region Enums
## The context the editor runs in. The host sets it via [method set_mode]; it gates whether modules can be
## dragged (and, later, whether the module tray is shown).
enum Mode {
	READ_ONLY,  ## Mid-combat: inspect only — no rearranging, no tray.
	EDIT,  ## Modify the current starship's modules (e.g. a shop). Drag to rearrange; tray available.
	SELECT,  ## Load out a starship at game start. Drag to rearrange; tray available.
}
#endregion

#region Constants
## DEBUG: the player's own loadout page (mounted via [method bind_session]) defaults to [constant
## Mode.EDIT] so drag-to-rearrange can be playtested before the shop / game-start flows exist to set the
## mode explicitly. Flip to false to default that page to [constant Mode.READ_ONLY] (fully locked).
const DEBUG_DEFAULT_EDIT := true

const _CELL_SIZE: float = 96.0
const _TILE_ICON_SIZE: float = 36.0
const _VALUE_WIDTH := 150.0
const _VALUE_FONT_SIZE := 28

# Stat value colors. A focused module shows each stat it touches as the resolved total with its signed
# contribution in parentheses (e.g. "4 (+4)"), tinted by whether the module helps ([_GAIN_COLOR]) or hurts
# ([_LOSS_COLOR]). Stats it doesn't touch — and every total with nothing focused — use [_TOTAL_COLOR].
const _TOTAL_COLOR := Color(0.93, 0.95, 1.0)
const _GAIN_COLOR := Color(0.45, 0.9, 0.5)
const _LOSS_COLOR := Color(0.96, 0.55, 0.45)
#endregion

#region Properties
var _mode: Mode = Mode.READ_ONLY
var _grid_view: ModuleGridView
var _module_grid: StarshipLoadout

# The module the player tapped to inspect (null when nothing is focused). Its footprint is outlined on
# the board and its per-stat contribution is split out of each stat total.
var _focused_module: ModuleState

# Drag-to-rearrange state. While a module is held, [_grabbed_cell] is the cell it was grabbed by and
# [_grabbed_cells] its full footprint; the held module keeps drawing in place and a validity-tinted
# ghost previews where it would land. (-1, -1) means nothing is held.
var _grabbed_cell := Vector2i(-1, -1)
var _grabbed_cells: Array[Vector2i] = []

@onready var _canvas: BoardCanvas = %BoardCanvas
@onready var _stat_list: VBoxContainer = %StatList
#endregion


#region Methods
func _ready() -> void:
	# Seed a fresh default game so the loadout and its stats render on their own — the dev preview (F6) and
	# the standalone scene both need a session, and there's no host that binds one. [LoadoutScreen] re-binds
	# the run it sets up immediately after this, so its session is the one that ends up shown.
	GameSession.start_new_game()
	bind_session()


## Mounts the player's module grid as the board and lists the stats its modules sum to. Called by the host
## screen ([LoadoutScreen]); reads the running game from the [code]GameSession[/code] autoload and defaults
## to an editable mode (the player's own loadout). Use [method show_starship] to point at another starship.
func bind_session() -> void:
	if GameSession.game_state == null or GameSession.game_state.starship == null:
		return
	set_mode(Mode.EDIT if DEBUG_DEFAULT_EDIT else Mode.READ_ONLY)
	_show_grid(GameSession.game_state.starship.loadout)


## Re-points the board at [param starship]'s loadout, shown [constant Mode.READ_ONLY] — for inspecting a
## starship you don't own. Rebuilds the board and stats.
func show_starship(starship: StarshipState) -> void:
	if starship == null:
		return
	set_mode(Mode.READ_ONLY)
	_show_grid(starship.loadout)


## Sets the screen's [enum Mode]; the shell picks it per context (see [enum Mode]). Clears any in-flight
## drag so flipping mode mid-gesture can't strand a preview ghost.
func set_mode(mode: Mode) -> void:
	_mode = mode
	_grabbed_cell = Vector2i(-1, -1)
	_grabbed_cells = []
	if _grid_view != null:
		_grid_view.clear_preview()


# Rebuilds the board and stat list for [param module_grid], freeing the prior view first
# ([BoardCanvas.set_board] detaches the old board but doesn't free it, so re-pointing would otherwise
# leak views) and re-pointing the stats at the shown starship.
func _show_grid(module_grid: StarshipLoadout) -> void:
	if module_grid == null:
		return
	if _module_grid != null and _module_grid.changed.is_connected(_on_grid_changed):
		_module_grid.changed.disconnect(_on_grid_changed)
	_module_grid = module_grid
	if _grid_view != null:
		_grid_view.queue_free()
	_grabbed_cell = Vector2i(-1, -1)
	_grabbed_cells = []
	_focused_module = null
	_grid_view = ModuleGridView.new()
	_grid_view.configure(_module_grid, _CELL_SIZE)
	_canvas.set_board(_grid_view, _grid_view.content_size())
	_canvas.input_handler = _on_board_input
	if not _module_grid.changed.is_connected(_on_grid_changed):
		_module_grid.changed.connect(_on_grid_changed)
	_apply_focus()


# True when the current [enum Mode] permits rearranging modules — the editable modes ([constant
# Mode.EDIT], [constant Mode.SELECT]). [constant Mode.READ_ONLY] (mid-combat) is inspect-only.
func _editable() -> bool:
	return _mode == Mode.EDIT or _mode == Mode.SELECT


# Pointer events forwarded from the [BoardCanvas] (positions already in global space). Finger 0 / left
# mouse picks up the module under the press; dragging it to another fitting cell moves it (editable
# starships only), while a press-and-release on the same module taps it into focus. A press on empty space
# clears the focus.
# gdlint:disable=max-returns
func _on_board_input(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.index != 0:
			return false
		return _press(touch.position) if touch.pressed else _release(touch.position)
	var drag := event as InputEventScreenDrag
	if drag != null:
		return _move_preview(drag.position) if drag.index == 0 else false
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		return _press(button.position) if button.pressed else _release(button.position)
	var motion := event as InputEventMouseMotion
	if motion != null:
		return _move_preview(motion.position)
	return false


# gdlint:enable=max-returns


# Picks up the module under [param global_position]; a press on empty space clears the focus instead.
# The footprint preview only appears on an editable board (the player's own starship, between combats).
func _press(global_position: Vector2) -> bool:
	var cell := _grid_view.cell_at(global_position)
	var placed := _module_grid.state_at(cell) if cell.x != -1 else null
	if placed == null:
		_set_focus(null)
		return false
	_grabbed_cell = cell
	_grabbed_cells = _module_grid.cells_at(cell)
	if _editable():
		_preview_at(cell)
	return true


# Re-previews the held footprint at the hovered cell (off-grid clears the preview). A no-op unless a
# module is held on an editable board, so plain mouse motion and view-only starships ignore it.
func _move_preview(global_position: Vector2) -> bool:
	if _grabbed_cell.x == -1 or not _editable():
		return false
	var cell := _grid_view.cell_at(global_position)
	if cell.x == -1:
		_grid_view.clear_preview()
	else:
		_preview_at(cell)
	return true


# Releases the held module: a move when it was dragged to another fitting cell on an editable board,
# otherwise a tap that focuses it. Either way the released module ends up focused.
func _release(global_position: Vector2) -> bool:
	if _grabbed_cell.x == -1:
		return false
	_grid_view.clear_preview()
	var from := _grabbed_cell
	var grabbed := _module_grid.module_at(from)
	_grabbed_cell = Vector2i(-1, -1)
	_grabbed_cells = []
	var cell := _grid_view.cell_at(global_position)
	if _editable() and cell.x != -1 and cell != from:
		_module_grid.move(from, cell)
	_set_focus(grabbed)
	return true


# Tints the held footprint at [param hover_cell] green (fits) or red (blocked / off the silhouette).
func _preview_at(hover_cell: Vector2i) -> void:
	var delta := hover_cell - _grabbed_cell
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _grabbed_cells:
		cells.append(cell + delta)
	_grid_view.set_preview(cells, _module_grid.can_move(_grabbed_cell, hover_cell))


# Focuses [param module] (or clears focus when null): outlines its footprint on the board, names it in
# the stat block, and splits its contribution out of each stat total.
func _set_focus(module: ModuleState) -> void:
	_focused_module = module
	_apply_focus()


# The grid changed under us (e.g. a module moved), so the focused module may have shifted or vanished.
func _on_grid_changed() -> void:
	_apply_focus()


# Reflects the current focus into the board outline (the module is named on its footprint, not here) and
# the stat list — where the focused module's contribution is split out of each stat total.
func _apply_focus() -> void:
	var cells := _focused_cells()
	if _focused_module != null and cells.is_empty():
		_focused_module = null  # the focused module is no longer on the grid
	if _grid_view != null:
		if _focused_module != null:
			_grid_view.set_focus(cells)
		else:
			_grid_view.clear_focus()
	_rebuild_stats()


# The cells the focused module currently occupies, or empty when nothing is focused / it's been removed.
func _focused_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _focused_module == null or _module_grid == null:
		return result
	for module_state: ModuleState in _module_grid.modules:
		if module_state == _focused_module:
			return _module_grid.cells_of(module_state)
	return result


# The stat readout: one row per stat-bearing match tile kind, each shown beside its tile, in [MatchTile]
# kind order. Each entry is [stat, label, tile kind]. The scrap (kind 4) and warp (kind 5) tiles aren't starship
# stats — scrap banks to the wallet, warp charges the encounter meter — so neither has a row.
func _stat_rows() -> Array:
	return [
		[Stats.power, "Power", 0],
		[Stats.speed, "Speed", 1],
		[Stats.sensors, "Sensors", 2],
		[Stats.defense, "Defense", 3],
		[Stats.weapons, "Weapons", 6],
	]


# Repopulates the stat list from the grid's current loadout: one row per stat, tile + name + value. When
# a module is focused, each stat it touches shows the resolved total with its signed contribution.
func _rebuild_stats() -> void:
	if _stat_list == null:
		return
	for child: Node in _stat_list.get_children():
		child.queue_free()
	var profile := _profile()
	var focus_stats: StarshipStats = _focused_module.stats if _focused_module != null else null
	_stat_list.add_child(_energy_row())
	for row: Array in _stat_rows():
		var stat: StarshipStat = row[0]
		var label: String = row[1]
		var tile_kind: int = row[2]
		var contribution: int = focus_stats.get_stat(stat) if focus_stats != null else 0
		_stat_list.add_child(_stat_row(label, tile_kind, _stat_value_text(profile.get_stat(stat), contribution), _value_color(contribution)))


# A stat profile summed from the loadout's modules (zeros when empty). The grid owns the counting rule
# (only fully-enabled modules count); the outfitting bay has no disabled cells, so this reads the lot.
func _profile() -> StarshipStats:
	return _module_grid.stats() if _module_grid != null else StarshipStats.new()


# One stat row: [tile][name ............ value]. The tile slot keeps its size even when the stat has no
# tile, so the name column stays aligned. The caller supplies the value text and its color (green/red when
# a focused module changes the stat — see [method _value_color]).
func _stat_row(label: String, tile_kind: int, value_text: String, value_color: Color) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	line.add_child(_tile_icon(tile_kind))

	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", _VALUE_FONT_SIZE)
	line.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.custom_minimum_size = Vector2(_VALUE_WIDTH, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", _VALUE_FONT_SIZE)
	value_label.add_theme_color_override("font_color", value_color)
	line.add_child(value_label)
	return line


# The energy row, shown as "used / generated": reactors generate energy, powered modules consume it. Only
# fully-enabled modules count, matching the stat profile's rule. Has no match tile, so the icon slot is empty.
func _energy_row() -> HBoxContainer:
	var used := 0
	var generated := 0
	if _module_grid != null:
		for module_state: ModuleState in _module_grid.modules:
			if module_state.stats == null or not _module_grid.enabled(module_state):
				continue
			var contribution := module_state.stats.energy
			if contribution > 0:
				generated += contribution
			else:
				used += -contribution
	return _stat_row("Energy", -1, "%d / %d" % [used, generated], _TOTAL_COLOR)


# The value color: green when the focused module raises this stat, red when it lowers it, the default
# total color when it doesn't touch it (or nothing is focused).
func _value_color(contribution: int) -> Color:
	if contribution > 0:
		return _GAIN_COLOR
	if contribution < 0:
		return _LOSS_COLOR
	return _TOTAL_COLOR


# The value cell text: the plain total, or — when the focused module touches this stat — the resolved
# total with the module's signed contribution in parentheses (e.g. "4 (+4)" for a stat it raises to 4,
# "0 (−2)" for one it drops to 0).
static func _stat_value_text(total: int, contribution: int) -> String:
	if contribution == 0:
		return str(total)
	var sign_text := "+" if contribution > 0 else "−"
	return "%d (%s%d)" % [total, sign_text, absi(contribution)]


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
#endregion
