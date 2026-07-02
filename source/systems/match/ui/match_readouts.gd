class_name MatchReadouts
extends RefCounted
## The match's portrait and warp UI: the two combatants' resource readouts, health bars, evade badges and module
## grids, the shared warp meter above the board, and the Jump call-to-action. Builds and repaints them through
## the shared [MatchContext] — reading the encounter and the rules engine (for warp capacity), owning only the
## warp segments and the Jump button it creates.

#region Constants

# The four colored stat tiles (combat, propulsion, science, defense) whose match counts show as resources
# beneath the portraits, in [MatchTile] kind order — index-aligned with PortraitPanel's strip.
const _STAT_KINDS: Array[int] = [0, 1, 2, 3]
const _WARP_KIND: int = 5
# Warp segment fills, keyed by which way the signed meter leans: positive is the player's progress (purple, the
# Warp tile color), negative the opponent's (red — the Quick Match tug). Only the leader's color shows.
const _WARP_FILL_POSITIVE := Color(0.66, 0.47, 0.86)
const _WARP_FILL_NEGATIVE := Color(0.88, 0.40, 0.42)

#endregion

#region Properties

var _ctx: MatchContext

# The four stat resources (combat, propulsion, science, defense), resolved from the catalog by tile kind and
# cached on first use — the readouts read these. Built lazily because Catalogs is an autoload that populates in
# its own _ready.
var _stat_resources: Array[StarshipResource] = []
# The shared warp meter's segment cells, left to right, sitting immediately above the board. Filled to show the
# meter's magnitude in the leader's color (see [method refresh_warp]).
var _warp_segments: Array[Panel] = []
# The "JUMP" call-to-action, shown only when the player has filled their warp meter (see [method refresh_jump]).
var _jump_button: Button

#endregion

#region Methods


func _init(ctx: MatchContext) -> void:
	_ctx = ctx


# Repaints both portraits fully: readouts, module grids, health, warp, the ability bar, and the Jump button. The
# flags gate the ability bar and Jump (usable only on the player's turn, not game-over, not mid-resolve).
func refresh_portraits(game_over: bool, resolving: bool) -> void:
	refresh_readouts()
	if _ctx.player_portrait != null:
		_ctx.player_portrait.set_module_grid(_ctx.rules.loadout_of(_ctx.rules.player_starship()))
	if _ctx.opponent_portrait != null:
		_ctx.opponent_portrait.set_module_grid(_ctx.rules.loadout_of(_ctx.rules.opponent_starship()))
	refresh_health()
	refresh_warp()
	_ctx.abilities.refresh_abilities(_is_player_turn() and not game_over and not resolving)
	refresh_jump(game_over, resolving)


# Repaints the top row (round, turn-of-round, whose turn) and highlights the active portrait.
func refresh_turn_labels() -> void:
	if _ctx.encounter == null:
		return
	if _ctx.round_label != null:
		_ctx.round_label.text = "ROUND %d" % _ctx.encounter.round_number
	if _ctx.turn_label != null:
		var who: String = _name_for(_ctx.encounter.active_combatant()).to_upper()
		_ctx.turn_label.text = "TURN %d / %d · %s" % [_ctx.encounter.turn_in_round, EncounterState.TURNS_PER_ROUND, who]
	if _ctx.player_portrait != null:
		_ctx.player_portrait.set_active(_ctx.encounter.active_combatant() == _ctx.encounter.player)
	if _ctx.opponent_portrait != null:
		_ctx.opponent_portrait.set_active(_ctx.encounter.active_combatant() == _ctx.encounter.opponent)


# Repaints both portraits' resource readouts from the starships' live tallies. Cheap and idempotent, so it runs
# once per cascade step (banked resources tick up as each match clears) as well as in the full portrait pass.
func refresh_readouts() -> void:
	if _ctx.player_portrait != null:
		_ctx.player_portrait.set_readouts(player_readouts())
	if _ctx.opponent_portrait != null:
		_ctx.opponent_portrait.set_readouts(opponent_readouts())


# Repaints both portraits' health bars from the encounter's current health.
func refresh_health() -> void:
	if _ctx.encounter == null:
		return
	if _ctx.player_portrait != null:
		_ctx.player_portrait.set_health(_ctx.encounter.player_health, _ctx.encounter.player_max_health, _ctx.encounter.shield_of(_ctx.encounter.player))
	if _ctx.opponent_portrait != null:
		_ctx.opponent_portrait.set_health(_ctx.encounter.opponent_health, _ctx.encounter.opponent_max_health, _ctx.encounter.shield_of(_ctx.encounter.opponent))
	refresh_dodge()


# Toggles each portrait's EVADE badge to match the encounter's dodge state — armed by Evasive Maneuvers, spent by
# the next attack, expired when the owner's turn returns — so a live dodge is always visible.
func refresh_dodge() -> void:
	if _ctx.encounter == null:
		return
	if _ctx.player_portrait != null:
		_ctx.player_portrait.set_dodge_active(_ctx.encounter.dodge_of(_ctx.encounter.player))
	if _ctx.opponent_portrait != null:
		_ctx.opponent_portrait.set_dodge_active(_ctx.encounter.dodge_of(_ctx.encounter.opponent))


# Repaints the warp bar above the board as a tug of war: the side currently ahead sets the bar's length to its
# own capacity and fills toward its own Jump — the player from the left (purple), the opponent from the right
# (red). Segments past the leader's capacity are hidden, so the bar's width tracks whoever is winning.
func refresh_warp() -> void:
	if _ctx.encounter == null or _warp_segments.is_empty():
		return
	var leads_player: bool = _ctx.encounter.warp_meter.value >= 0
	var capacity: int = _ctx.encounter.warp_meter.capacity_of(leads_player)
	var level: int = absi(_ctx.encounter.warp_meter.value)
	var fill: Color = _WARP_FILL_POSITIVE if leads_player else _WARP_FILL_NEGATIVE
	for i: int in _warp_segments.size():
		var visible: bool = i < capacity
		_warp_segments[i].visible = visible
		if not visible:
			continue
		# Player fills left-to-right (the first `level` cells); the opponent fills right-to-left (the last
		# `level` cells of its capacity), so each side charges from its own edge of the meter.
		var filled: bool = (i < level) if leads_player else (i >= capacity - level)
		_paint_warp_segment(_warp_segments[i], filled, fill)


# The four resource readouts beneath the player portrait, in [constant _STAT_KINDS] order (combat, propulsion,
# science, defense): the tiles the player has matched of each kind this encounter. Starts at zero — these are
# matched-this-fight resources, not the starship's base stats (those live on the stats screen).
func player_readouts() -> PackedStringArray:
	return _readouts_for(_ctx.encounter.player if _ctx.encounter != null else null)


# The opponent's four resource readouts — its own matched-this-encounter resources.
func opponent_readouts() -> PackedStringArray:
	return _readouts_for(_ctx.encounter.opponent if _ctx.encounter != null else null)


# Sets the encounter's warp mode for this board: [param tug] runs warp as a two-way tug (the opponent can win on
# it too), else a one-way meter the opponent only drains. Seeds each side's warp capacity from its starship's
# warp-core modules, so the warp bar is sized by what a starship carries rather than a fixed constant.
func configure_warp(tug: bool) -> void:
	if _ctx.encounter == null:
		return
	_ctx.encounter.warp_meter.tug = tug
	_ctx.encounter.warp_meter.player_capacity = _warp_capacity_of(_ctx.encounter.player)
	_ctx.encounter.warp_meter.opponent_capacity = _warp_capacity_of(_ctx.encounter.opponent)


# Fills both combatants to full hull at the start of an encounter — max is the starship's own derived hull (base
# health stat plus any hull modules), so HP is starship-driven. A side with no combatant is skipped.
func configure_health() -> void:
	if _ctx.encounter == null:
		return
	for combatant: Combatant in [_ctx.encounter.player, _ctx.encounter.opponent]:
		if combatant != null:
			combatant.set_health(combatant.max_health())


# Whether warp is in play this board: the WarpRule must be ruled in and enabled, and at least one starship must
# carry a warp core — if neither can warp, there's nothing to charge, so warp tiles don't spawn and no meter is
# built.
func warp_active() -> bool:
	var rule := _find_warp_rule()
	if rule == null or not rule.enabled:
		return false
	return _ctx.encounter != null and (_ctx.encounter.warp_meter.player_capacity > 0 or _ctx.encounter.warp_meter.opponent_capacity > 0)


# Builds the warp meter once, the first time warp is active for this board — the capacity isn't known until a
# session binds its starships, so the bar can't be built unconditionally in _ready like the rest of the UI.
func ensure_warp_bar() -> void:
	if _warp_segments.is_empty() and warp_active():
		_build_warp_bar()


# Builds the "JUMP" call-to-action: a bold, warp-colored button low over the board, hidden until the player fills
# their warp meter. Wired to [param on_pressed] (the coordinator's jump flow).
func build_jump_button(on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = "JUMP"
	button.visible = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(220, 88)
	button.add_theme_font_size_override("font_size", 40)
	# Centered horizontally, sitting low so it reads as a "you can win now" prompt without burying the board.
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	button.offset_bottom = -140.0
	var warp_color: Color = MatchTile.color_of(_WARP_KIND)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(warp_color.r, warp_color.g, warp_color.b, 0.9)
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = Color.WHITE
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(on_pressed)
	_ctx.root.add_child(button)
	_jump_button = button


# Shows the Jump button only when the player has filled their warp and can cash it in — and not mid-resolve or
# after the encounter's been decided.
func refresh_jump(game_over: bool, resolving: bool) -> void:
	if _jump_button == null:
		return
	_jump_button.visible = _ctx.encounter != null and not game_over and not resolving and _ctx.encounter.warp_meter.can_jump(true)


# The display name of the combatant whose turn it currently is (the player's when there's no encounter).
func active_name() -> String:
	if _ctx.encounter == null:
		return _ctx.player_portrait.portrait_name
	return _name_for(_ctx.encounter.active_combatant())


# The portrait name of [param combatant] (the opponent's when it is the opponent, else the player's).
func name_for(combatant: Combatant) -> String:
	return _name_for(combatant)


# A combatant's four stat-tile readouts: the count matched of each resource this fight, read off the encounter.
func _readouts_for(combatant: Combatant) -> PackedStringArray:
	var out := PackedStringArray()
	for resource: StarshipResource in _stat_resources_cached():
		out.append(str(_resource_of(combatant, resource)))
	return out


# A combatant's banked count of a resource this encounter (zero when there's no combatant).
func _resource_of(combatant: Combatant, resource: StarshipResource) -> int:
	return combatant.resource_of(resource) if combatant != null else 0


# The four stat resources, resolved once from the catalog (index-aligned with [constant _STAT_KINDS]).
func _stat_resources_cached() -> Array[StarshipResource]:
	if _stat_resources.is_empty():
		for kind: int in _STAT_KINDS:
			var resource: StarshipResource = Catalogs.ability_resources.for_tile(kind)
			if resource != null:
				_stat_resources.append(resource)
	return _stat_resources


# [param combatant]'s warp capacity — the warp_capacity their slotted modules sum to (a disabled core stops
# counting, like any module). Zero means the starship carries no warp core and can't warp.
func _warp_capacity_of(combatant: Combatant) -> int:
	return _ctx.rules.effective_stats(combatant).warp_capacity


# The active WarpRule in the encounter's ruleset, or null if warp isn't ruled in — its enabled flag is the
# match-level warp switch (see [method warp_active]).
func _find_warp_rule() -> WarpRule:
	if _ctx.ruleset == null:
		return null
	for rule: Rule in _ctx.ruleset.resolved():
		if rule is WarpRule:
			return rule as WarpRule
	return null


# The most segments the meter ever needs: the larger of the two sides' capacities, since the bar shows the
# leader's capacity and the lead can swing either way.
func _max_warp_segments() -> int:
	if _ctx.encounter == null:
		return 0
	return maxi(_ctx.encounter.warp_meter.player_capacity, _ctx.encounter.warp_meter.opponent_capacity)


# Whether it's the player's turn (or there's no encounter, e.g. the standalone scene — then always theirs).
func _is_player_turn() -> bool:
	return _ctx.encounter == null or _ctx.encounter.active_combatant() == _ctx.encounter.player


# The portrait name of [param combatant] (the opponent's on its turn, else the player's).
func _name_for(combatant: Combatant) -> String:
	return _ctx.opponent_portrait.portrait_name if _ctx.encounter != null and combatant == _ctx.encounter.opponent else _ctx.player_portrait.portrait_name


# Builds the warp meter — a row of [method _max_warp_segments] segment cells — and slots it into the layout
# immediately above the board. Filled by [method refresh_warp] to show how charged the meter is.
func _build_warp_bar() -> void:
	var board_panel: Node = _ctx.canvas.get_parent() if _ctx.canvas != null else null
	if board_panel == null:
		return
	var body := board_panel.get_parent() as VBoxContainer
	if body == null:
		return
	var row := HBoxContainer.new()
	row.name = "WarpBar"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var caption := Label.new()
	caption.text = "WARP"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color(0.66, 0.72, 0.85))
	row.add_child(caption)

	_warp_segments.clear()
	for _i: int in _max_warp_segments():
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(0, 20)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(seg)
		_warp_segments.append(seg)

	body.add_child(row)
	body.move_child(row, board_panel.get_index())  # sit immediately above the board
	refresh_warp()


# Paints one warp segment: the leader's fill (bright, white-edged) when charged, a dim empty cell otherwise.
func _paint_warp_segment(seg: Panel, filled: bool, fill: Color) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	if filled:
		style.bg_color = fill
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.5)
	else:
		style.bg_color = Color(0.12, 0.13, 0.21, 0.6)
		style.set_border_width_all(1)
		style.border_color = Color(1, 1, 1, 0.08)
	seg.add_theme_stylebox_override("panel", style)

#endregion
