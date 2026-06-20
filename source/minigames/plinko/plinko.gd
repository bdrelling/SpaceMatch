class_name PlinkoMinigame
extends Minigame
## Plinko minigame (recycling sandbox, not wired to a tab): a plinko machine that consumes scrap from the
## session inventory and produces
## components, rarely a damaged module. Tapping drops the scrap marker sliding across the top (small
## 1 ball, medium 2, large 3); a ball landing in a slot pays that slot's component and, unless the
## player has tapped to lock it, changes its type. Match all three slots on one type → damaged module.
##
## The scene is just the board; the shell renders the on-hand totals as the inventory strip (category
## chips, with a tap-to-expand breakdown of every stack) and the scrap line as [member status_text].

const _BOARD_SIZE := Vector2(720.0, 1040.0)

const _SCRAP: ItemBlueprint = preload("res://resources/items/scrap/scrap_item_blueprint.tres")

const _RECIPE: WeightedRecipeBlueprint = preload("res://resources/recipes/recycling/recycle_scrap.tres")

## Balls dropped per scrap fed. Scrap is a flat quantity now, so each feed drops the same spread.
const _BALLS_PER_FEED := 2

# A fresh arcade game starts with an empty inventory, so stock scrap to recycle (matches Outfitting,
# which seeds starter modules). Only seeds when no scrap is present, so it never piles up on rebind.
const _STARTER_SCRAP := 340

## Chip swatches in the shell's inventory strip.
const _SCRAP_COLOR := Color(0.78, 0.52, 0.25)
const _COMPONENT_COLOR := Color(0.45, 0.72, 0.55)
const _MODULE_COLOR := Color(0.55, 0.62, 0.78)

@onready var _canvas: BoardCanvas = %BoardCanvas

var _inventory: Inventory
var _board: PlinkoBoard
var _gestures: GestureRecognizer
var _detail: ScrollContainer
var _detail_list: VBoxContainer

func _ready() -> void:
	_board = PlinkoBoard.new()
	_board.recycled.connect(_on_output)
	_board.jackpot.connect(_on_output)
	_board.build(_ordered_outputs(_RECIPE))
	_canvas.set_board(_board, _BOARD_SIZE)

	# Route board taps through the recognizer like the other minigames, so a tap reads as a tap (not
	# the start of a page swipe) and off-board touches still reach the arcade pager.
	_gestures = GestureRecognizer.new()
	_gestures.cell_resolver = _resolve_cell
	_gestures.tap.connect(_on_tap)
	_gestures.set_process_unhandled_input(false)
	add_child(_gestures)
	_canvas.input_handler = _gestures.handle_event

	_update_status()

## Wires the minigame to the running game's session inventory — the same economy the overworld
## reads. Called by [MinigameScreen] when the arcade mounts this page.
func bind_session(_session: GameSession, inventory: Inventory) -> void:
	if _inventory != null and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
	_inventory = inventory
	if _inventory != null:
		_inventory.changed.connect(_on_inventory_changed)
	_seed_starter_scrap()
	_update_status()

func _on_inventory_changed(_inventory_node: Inventory) -> void:
	_update_status()

func _seed_starter_scrap() -> void:
	if _inventory == null:
		return
	if _inventory.count(_SCRAP.id) > 0:
		return
	var no_tags: Array[Item.Tag] = []
	_inventory.add_variant(_SCRAP, no_tags, _STARTER_SCRAP)

# A tap on a slot locks/unlocks it; a tap anywhere else on the board drops the sliding scrap. Off the
# board returns NO_CELL so the recognizer ignores it and the pager can still swipe in the margins.
func _resolve_cell(screen_position: Vector2) -> Vector2i:
	if not _board.contains_global(screen_position):
		return GestureRecognizer.NO_CELL
	var slot_index := _board.slot_index_at(screen_position)
	if slot_index >= 0:
		return Vector2i(slot_index, 1)
	return Vector2i(0, 0)

func _on_tap(cell: Vector2i) -> void:
	if cell.y == 1:
		_board.lock_slot(cell.x)
	else:
		_feed_scrap()

## Recycles one piece of scrap, dropping a fixed spread of balls.
func _feed_scrap() -> void:
	if _inventory == null:
		return
	if _inventory.count(_SCRAP.id) <= 0:
		status_text = "No scrap to recycle"
		return
	_inventory.remove(_SCRAP.id, 1)
	_board.drop_balls(_BALLS_PER_FEED, _ordered_outputs(_RECIPE))
	_update_status()

func _on_output(output: ItemStack) -> void:
	if _inventory != null and output != null and output.item_blueprint != null:
		_inventory.add_variant(output.item_blueprint, output.tags, maxi(output.quantity, 1))
	_update_status()

## The recipe's possible yields as an ordered list — the slots index into this.
func _ordered_outputs(recipe: WeightedRecipeBlueprint) -> Array[ItemStack]:
	var outputs: Array[ItemStack] = []
	if recipe.weighted_outputs == null:
		return outputs
	for entry: WeightedEntry in recipe.weighted_outputs.entries:
		var stack := entry.value as ItemStack
		if stack != null:
			outputs.append(stack)
	return outputs

func _update_status() -> void:
	if _inventory == null:
		status_text = "Plinko — no inventory bound"
		return
	status_text = "Scrap: %d — tap the board to feed" % _inventory.count(_SCRAP.id)
	_rebuild_detail()
	inventory_changed.emit()

#region View-model

func inventory_chips() -> Array[InventoryChip]:
	var chips: Array[InventoryChip] = []
	if _inventory == null:
		return chips
	var scrap: int = 0
	var components: int = 0
	var modules: int = 0
	for stack: ItemStack in _inventory.get_stacks():
		if stack.item_blueprint == null:
			continue
		match stack.item_blueprint.category:
			Item.Category.SCRAP:
				scrap += stack.quantity
			Item.Category.COMPONENT:
				components += stack.quantity
			Item.Category.MODULE:
				modules += stack.quantity
	chips.append(InventoryChip.new("Scrap", scrap, _SCRAP_COLOR))
	chips.append(InventoryChip.new("Components", components, _COMPONENT_COLOR))
	chips.append(InventoryChip.new("Modules", modules, _MODULE_COLOR))
	return chips

# Tap-to-expand: the full per-stack breakdown the strip can't fit, in a scrolling list.
func inventory_detail() -> Control:
	if _detail == null:
		_detail = ScrollContainer.new()
		_detail.custom_minimum_size = Vector2(0, 360)
		_detail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_detail_list = VBoxContainer.new()
		_detail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detail.add_child(_detail_list)
		_rebuild_detail()
	return _detail

func _rebuild_detail() -> void:
	if _detail_list == null:
		return
	for child: Node in _detail_list.get_children():
		child.queue_free()
	if _inventory == null:
		return
	for stack: ItemStack in _inventory.get_stacks():
		if stack.item_blueprint == null or stack.quantity <= 0:
			continue
		var row := Label.new()
		row.text = "%s  ×%d" % [stack.display_name, stack.quantity]
		_detail_list.add_child(row)

#endregion
