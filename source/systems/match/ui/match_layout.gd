class_name MatchLayout
extends Node
## Reflows the match screen's middle band by orientation. Portrait (the authored default) stacks the two
## portraits in a row above the board; landscape lays out a three-column stack — [PlayerPortrait | BoardPanel |
## OpponentPortrait]. The board column hugs a square (its width tracks its height) and the two portraits expand
## to fill everything left over, so they sit flush against the board with no gap. The three widgets are stateful
## singletons the game holds refs to, so they're REPARENTED between the authored [code]Hud[/code] and a runtime
## [code]BattleRow[/code] rather than duplicated. Re-evaluated on every viewport [signal Viewport.size_changed];
## being a [Node] in the tree, the connection tears down with it (no manual disconnect).

#region Constants
## Multiplier on each bar's height in landscape, where there's vertical room to spare. Separate knobs for the
## warp meter and the ability bar so they can diverge later; the same value for now.
const _WARP_LANDSCAPE_SCALE: float = 2.0
const _ACTIONS_LANDSCAPE_SCALE: float = 2.0
## The warp meter's portrait baseline. It's segment-driven and otherwise collapses to its caption, so it needs
## an explicit height to scale from.
const _WARP_BASE_HEIGHT: float = 24.0
## The runtime name [MatchReadouts] gives the warp meter row (added to [member _body]).
const _WARP_BAR_NAME: StringName = &"WarpBar"
#endregion

#region Properties
var _body: VBoxContainer
var _hud: HBoxContainer
var _battle_row: HBoxContainer
var _board_panel: PanelContainer
var _actions: Control
var _player: PortraitPanel
var _opponent: PortraitPanel
# The authored ability-bar height, captured in setup so the revert restores the scene rather than a hardcoded copy.
var _actions_height: float = 0.0
# The applied layout, so a resize that doesn't cross the aspect boundary is a no-op. Unset until the first
# _apply, which lets the initial pass run — and no-op when it lands on the authored portrait.
var _landscape: bool = false
var _applied: bool = false
#endregion


#region Methods
## Stores the nodes to reflow and captures the authored ability-bar height. Called once by [MatchGame] before it
## enters the tree, so the refs are set when [method _ready] connects and applies.
func setup(
	body: VBoxContainer,
	hud: HBoxContainer,
	battle_row: HBoxContainer,
	board_panel: PanelContainer,
	actions: Control,
	player: PortraitPanel,
	opponent: PortraitPanel
) -> void:
	_body = body
	_hud = hud
	_battle_row = battle_row
	_board_panel = board_panel
	_actions = actions
	_player = player
	_opponent = opponent
	_actions_height = actions.custom_minimum_size.y


func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	# Keep the board column square as the row resizes; catch the warp meter whenever it's built (it can appear
	# after the first layout, once a session binds and its capacity is known).
	_board_panel.resized.connect(_fit_board_column)
	_body.child_entered_tree.connect(_on_body_child_entered)
	_apply()


# Reflows to match the viewport aspect, skipping when the applied layout already matches. The authored tree is
# portrait, so the very first pass in portrait needs no work.
func _apply() -> void:
	var rect: Vector2 = get_viewport().get_visible_rect().size
	var landscape: bool = rect.x > rect.y
	if _applied and landscape == _landscape:
		return
	var first: bool = not _applied
	_applied = true
	_landscape = landscape
	if landscape:
		_to_landscape()
	elif not first:
		_to_portrait()


# Three-column stack: portraits flank the board in the BattleRow. The board column is FILL (so it takes only its
# min width, kept square by _fit_board_column) and the portraits keep their authored EXPAND_FILL, so they expand
# into the leftover width flush against the board. The stacked Hud (with its Versus label) hides.
func _to_landscape() -> void:
	_hud.visible = false
	_battle_row.visible = true
	_player.reparent(_battle_row, false)
	_board_panel.reparent(_battle_row, false)
	_opponent.reparent(_battle_row, false)
	_board_panel.size_flags_horizontal = Control.SIZE_FILL
	_apply_bar_heights()
	_fit_board_column.call_deferred()  # size.y isn't settled until the reparented row lays out


# Restore the authored portrait stack: portraits back in the Hud flanking Versus, board below the Hud, bars reset.
func _to_portrait() -> void:
	_player.reparent(_hud, false)
	_hud.move_child(_player, 0)
	_opponent.reparent(_hud, false)
	_hud.move_child(_opponent, _hud.get_child_count() - 1)
	_board_panel.reparent(_body, false)
	_body.move_child(_board_panel, _hud.get_index() + 1)
	_board_panel.size_flags_horizontal = Control.SIZE_FILL
	_board_panel.custom_minimum_size.x = 0.0
	_apply_bar_heights()
	_hud.visible = true
	_battle_row.visible = false


# In landscape, pin the board column's width to its height so it stays a flush square with no side gap. Guarded
# so setting the min width (which re-fires resized) settles instead of looping, and left alone in portrait.
func _fit_board_column() -> void:
	if not _landscape:
		return
	var square: float = _board_panel.size.y
	if not is_equal_approx(_board_panel.custom_minimum_size.x, square):
		_board_panel.custom_minimum_size.x = square


func _apply_bar_heights() -> void:
	_actions.custom_minimum_size.y = _actions_height * _ACTIONS_LANDSCAPE_SCALE if _landscape else _actions_height
	_apply_warp_height()


# Taller in landscape, back to its natural (caption) height in portrait. No-op until the warp meter is built.
func _apply_warp_height() -> void:
	var warp := _body.get_node_or_null(NodePath(_WARP_BAR_NAME)) as Control
	if warp == null:
		return
	warp.custom_minimum_size.y = _WARP_BASE_HEIGHT * _WARP_LANDSCAPE_SCALE if _landscape else 0.0


func _on_body_child_entered(node: Node) -> void:
	if node.name == _WARP_BAR_NAME:
		_apply_warp_height()
#endregion
