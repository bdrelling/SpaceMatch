class_name PlayerGridInventoryPanel
extends GridInventoryPanel
## The player's inventory shelf: the quickbar row lives at the bottom of the screen and
## expands in place. Closed, only that row shows — chrome faded out, the rest of the grid
## below the screen edge. Open, the shelf slides up, fading in the panel and title and
## revealing the full grid, quickbar row split from the rest by a section gap. Number keys
## select a quickbar column; drops eject into the world via the player.

const SCENE_PATH := "res://systems/inventory/ui/grid_inventory_panel/player_grid_inventory_panel.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## Bottom inset of the quickbar row while the shelf is closed.
const CLOSED_ROW_MARGIN := 16.0

signal selected_slot_changed(column: int)

@export var player: Player

## Column highlighted on the quickbar row, driven by the quickbar_slot_* actions.
var selected_slot: int = 0:
	set(value):
		selected_slot = clampi(value, 0, maxi(_view.column_count() - 1, 0)) if is_node_ready() else value
		if is_node_ready():
			_view.selected_column = selected_slot
		selected_slot_changed.emit(selected_slot)

# 0 = quickbar strip only, 1 = full shelf; drives both the slide and the chrome fade.
var _openness := 0.0

@onready var _box: PanelContainer = %Box
@onready var _header: HBoxContainer = %Header

func _ready() -> void:
	super._ready()
	_view.selected_column = selected_slot
	resized.connect(_apply_shelf_layout)
	_box.resized.connect(_apply_shelf_layout)
	# The slide distance depends on where the view rests inside the box — recompute once the
	# containers have actually laid it out (and again whenever the header reflows it).
	_view.item_rect_changed.connect(_apply_shelf_layout)
	if player:
		bind_player(player)

## Points the shelf at [param player], tracking their inventory. Pass null to clear.
func bind_player(value: Player) -> void:
	player = value
	register(player.inventory if player else null)

#region Shelf presentation

## The shelf never hides: closed just means slid down to the quickbar strip with the chrome
## faded out.
func _apply_closed() -> void:
	content.visible = true
	_set_mouse_transparent(true)
	_set_openness(0.0)

func _animate(opening: bool) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_openness, _openness, 1.0 if opening else 0.0, duration)

func _set_openness(value: float) -> void:
	_openness = value
	_box.self_modulate.a = value
	_header.modulate.a = value
	_apply_shelf_layout()

# Repositions the box for the current openness; re-run whenever container layout settles.
func _apply_shelf_layout() -> void:
	var rest_y := size.y - _box.size.y
	var strip_bottom := _view.global_position.y - _box.global_position.y + float(_view.cell_size)
	var slide := maxf(_box.size.y - strip_bottom - CLOSED_ROW_MARGIN, 0.0)
	_box.position.y = rest_y + slide * (1.0 - _openness)

# Closed, the strip must not eat clicks meant for the world — only the open shelf is solid.
func _set_mouse_transparent(transparent: bool) -> void:
	var filter := Control.MOUSE_FILTER_IGNORE if transparent else Control.MOUSE_FILTER_STOP
	_box.mouse_filter = filter
	_view.mouse_filter = filter

func _on_opened() -> void:
	super()
	_set_mouse_transparent(false)

func _on_closed() -> void:
	super()
	_set_mouse_transparent(true)

#endregion

func _unhandled_input(event: InputEvent) -> void:
	super(event)
	_handle_slot_keys(event)

# Number keys select a quickbar column whether the shelf is open or closed. Open reads the
# event directly — BLOCK_ALL silences the actions through ManagedInput (the documented
# pairing in [member OverlayPanel.input_policy]).
func _handle_slot_keys(event: InputEvent) -> void:
	for index in InputAction.QUICKBAR_SLOTS.size():
		var action := InputAction.QUICKBAR_SLOTS[index]
		var pressed := event.is_action_pressed(action) if is_open \
				else ManagedInput.event_is_action_pressed(event, action)
		if pressed:
			selected_slot = index
			get_viewport().set_input_as_handled()
			return

## Ejects the item into the world via the player rather than just deleting it.
func _drop_stack(stack: ItemStack) -> void:
	if player and stack and stack.item_blueprint:
		player.drop_item(stack)

static func create(_player: Player = null) -> PlayerGridInventoryPanel:
	var panel: PlayerGridInventoryPanel = SCENE.instantiate()
	panel.player = _player
	return panel
