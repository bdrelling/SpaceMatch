class_name InventoryQuickbar
extends Control
## Standalone HUD strip showing row 0 of a grid inventory, with number-key slot selection.
## Not used by the player's unified inventory shelf ([GridInventoryPanel]) — kept for
## inventories that want only their quickbar row on screen (e.g. a decoupled grid).
## Selection is UI state only; [signal selected_slot_changed] is for future consumers.

const SCENE_PATH := "res://systems/inventory/ui/quickbar/inventory_quickbar.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

signal selected_slot_changed(column: int)

var inventory: Inventory

var selected_slot: int = 0:
	set(value):
		selected_slot = clampi(value, 0, maxi(_view.column_count() - 1, 0)) if is_node_ready() else value
		if is_node_ready():
			_view.selected_column = selected_slot
		selected_slot_changed.emit(selected_slot)

var _suppressed := false

@onready var _view: InventoryGridView = %View

func _ready() -> void:
	_view.selected_column = selected_slot

func bind_player(player: Player) -> void:
	register(player.inventory)

## Shows row 0 of [param value]; hides the strip entirely for non-grid inventories.
func register(value: Inventory) -> void:
	inventory = value
	_view.register(inventory)
	_refresh_visibility()

## Hides the strip while [param value] — for when its row is already on screen elsewhere
## (e.g. an expanded inventory panel).
func set_suppressed(value: bool) -> void:
	_suppressed = value
	_refresh_visibility()

func _refresh_visibility() -> void:
	visible = not _suppressed and inventory != null and inventory.capacity_rule is GridCapacityRule

func _unhandled_input(event: InputEvent) -> void:
	for index in InputAction.QUICKBAR_SLOTS.size():
		if ManagedInput.event_is_action_pressed(event, InputAction.QUICKBAR_SLOTS[index]):
			selected_slot = index
			get_viewport().set_input_as_handled()
			return

static func create() -> InventoryQuickbar:
	return SCENE.instantiate()
