class_name MatchEndState
extends RefCounted
## The match's end-of-fight and dead-board UI: the win/lose overlay, the stalemate resource split when a board
## dead-locks, and the debug move-count chip. Reads the encounter and the sibling collaborators through the
## shared [MatchContext]; owns only the overlay and the debug label it builds. The game-over / ended / reshuffle
## flags stay on the coordinator — this never writes them.

#region Constants

const _SCRAP_KIND: int = 4
const _WARP_KIND: int = 5
const _DAMAGE_KIND: int = 6

#endregion

#region Properties

var _ctx: MatchContext

# The win/lose overlay (Quick Match only), parented to the match screen, held so the restart can tear it down.
var _end_overlay: Control
# A flat-colored debug chip over the board showing the live available-move count; remove with its build call.
var _move_debug_label: Label
# True while a reshuffle is rebuilding the board, so the regenerate it triggers doesn't re-check and recurse.
var _reshuffling: bool = false

#endregion

#region Methods


func _init(ctx: MatchContext) -> void:
	_ctx = ctx


# Builds the full-screen win/lose overlay: a dimmer, the verdict, and a Restart button wired to [param on_restart].
# Player down → GAME OVER; opponent down → YOU WIN. The overlay eats input so the frozen board can't be touched.
func show_end_overlay(on_restart: Callable) -> void:
	if _end_overlay != null:
		return
	var player_won: bool = _ctx.encounter.defeated() == _ctx.encounter.opponent
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.09, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)

	var title := Label.new()
	title.text = "YOU WIN" if player_won else "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.52, 0.86, 0.60) if player_won else Color(0.88, 0.40, 0.42))
	column.add_child(title)

	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(240, 76)
	restart.add_theme_font_size_override("font_size", 32)
	restart.pressed.connect(on_restart)
	column.add_child(restart)

	_ctx.root.add_child(overlay)
	_end_overlay = overlay


func hide_end_overlay() -> void:
	if _end_overlay != null:
		_end_overlay.queue_free()
		_end_overlay = null


# Divides every tile on the current board between the two combatants as resources, each taking the floor of half
# a kind's count (the odd tile is discarded). Banks the four stat kinds into both tallies and scrap into the
# player's wallet; damage and warp aren't bankable resources, so they're left out. A no-op when the rule is off.
# Players call this a stalemate payout — the board you couldn't clear isn't simply lost.
func split_board_resources() -> void:
	var rule := _ctx.rules.rule_of(ReloadSplitRule) as ReloadSplitRule
	if rule == null or _ctx.encounter == null or _ctx.session == null:
		return
	var board: GridState = _ctx.session.state
	if board == null:
		return
	# The rule owns the share computation; the host applies it — which kind banks where is the host's economy.
	var shares: Dictionary = rule.shares(board)
	for kind: int in shares:
		var each: int = shares[kind]
		if each <= 0:
			continue
		match kind:
			_SCRAP_KIND:
				_ctx.resolver.earn_scrap(each)  # only the player banks scrap (the opponent has no wallet)
			_DAMAGE_KIND, _WARP_KIND:
				pass  # neither damage nor warp is a banked resource
			_:
				var resource: StarshipResource = Catalogs.ability_resources.for_tile(kind)
				if resource == null:
					continue
				var player_starship: Combatant = _ctx.encounter.player
				var opponent_starship: Combatant = _ctx.encounter.opponent
				if player_starship != null:
					player_starship.add_resource(resource, each)
				if opponent_starship != null:
					opponent_starship.add_resource(resource, each)
	# Reflect the freshly-banked resources in both portraits. A split only ever runs on a live board (a stalemate
	# reshuffle or the test), never game-over or mid-resolve, so both readout gates read false.
	_ctx.readouts.refresh_portraits(false, false)


# Drops the whole board off the bottom, regenerates, and pours a fresh one in — the dead-board reset. Waits out the
# rebuild before returning. Sets the reshuffle guard so the regenerate it triggers doesn't recurse.
func reshuffle_board() -> void:
	_reshuffling = true
	split_board_resources()  # divide the dead board's tiles between the combatants first (a no-op if the rule is off)
	_ctx.set_status.call("No moves — board split, reshuffling.")
	await _ctx.match_view.drop_out()
	_ctx.session.regenerate()  # rebuilds the tiles and (via on_regenerated) drops them in
	while _ctx.match_view.is_busy():
		await _ctx.match_view.get_tree().process_frame
	_reshuffling = false
	refresh_move_debug()


# Recenters and pours the freshly generated board in, then re-checks for a dead board — but not mid-reshuffle (a
# reshuffle regenerates too, which would recurse). Wired to [signal GridSession.regenerated].
func on_regenerated() -> void:
	if _ctx.grid == null:
		return
	_ctx.canvas.recenter()
	await _ctx.match_view.drop_in()
	refresh_move_debug()
	if not _reshuffling and not has_moves():
		await reshuffle_board()


# Whether the board has a move to play. Unknown for non-swap modes (no cheap test) counts as "yes", so only a
# confirmed dead swap board reshuffles.
func has_moves() -> bool:
	return available_moves() != 0


# Count of adjacent swaps that would make a match, or -1 when there's no cheap way to know (non-swap modes).
func available_moves() -> int:
	if _ctx.input_mode != MatchBoardView.InputMode.SWAP or _ctx.session == null or _ctx.session.state == null:
		return -1
	var swap := _ctx.session.find_interaction(GridInteraction.Gesture.SWIPE) as SwapInteraction
	if swap == null:
		return -1
	return SwapSolver.count_moves(_ctx.session.state, swap)


# Builds the debug move-count chip: monospace on a flat-blue panel at the top center, deliberately ugly so it's
# obvious it's debug-only. Delete this call (and refresh_move_debug's) to remove it.
func build_move_debug() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centered on its own width at the very top (anchors at 0.5 + grow-both is the self-sizing-centered idiom).
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_top = 8
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.9)  # flat blue — a "remove me" color
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.theme = load("res://ui/themes/debug.tres")
	label.theme_type_variation = &"DebugLabel"
	label.text = "moves: ?"
	panel.add_child(label)
	_ctx.root.add_child(panel)
	_move_debug_label = label


# Updates the debug chip with the live move count ("n/a" for modes without a count).
func refresh_move_debug() -> void:
	if _move_debug_label == null:
		return
	var moves: int = available_moves()
	_move_debug_label.text = "moves: %d" % moves if moves >= 0 else "moves: n/a"

#endregion
