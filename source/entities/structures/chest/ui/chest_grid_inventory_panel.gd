class_name ChestGridInventoryPanel
extends GridInventoryPanel
## Storage panel for a [Chest]: the chest's grid above the player's, opened and closed by the
## player's interaction signals. Clicking a stack transfers it whole into the other inventory
## (no pick-up-and-place) via [method Inventory.transfer_to].

const SCENE_PATH := "res://entities/structures/chest/ui/chest_grid_inventory_panel.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## The player whose interactions open the panel and whose inventory fills the lower grid.
## Wire in the editor (a sibling in the level scene).
@export var player: Player

var chest: Chest

@onready var _player_view: InventoryGridView = %PlayerView
@onready var _player_capacity: Label = %PlayerCapacity

func _ready() -> void:
	super._ready()
	_player_view.cell_pressed.connect(_on_player_cell_pressed)
	if player:
		bind_player(player)

## Points the panel at [param player], tracking their inventory and interactions. Pass null
## to clear.
func bind_player(value: Player) -> void:
	if player and player.structure_interacted.is_connected(_on_structure_interacted):
		player.structure_interacted.disconnect(_on_structure_interacted)
		player.structure_exited.disconnect(_on_structure_exited)
	if player and player.inventory and player.inventory.changed.is_connected(_on_player_inventory_changed):
		player.inventory.changed.disconnect(_on_player_inventory_changed)
	player = value
	if player:
		player.structure_interacted.connect(_on_structure_interacted)
		player.structure_exited.connect(_on_structure_exited)
		player.inventory.changed.connect(_on_player_inventory_changed)
	if is_node_ready():
		_player_view.register(player.inventory if player else null)
		_refresh_player_capacity()

func _on_structure_interacted(structure: Structure) -> void:
	var interacted_chest := structure as Chest
	if interacted_chest == null:
		return
	if is_open and chest == interacted_chest:
		close()
		return
	chest = interacted_chest
	register(chest.inventory)
	open()

func _on_structure_exited(structure: Structure) -> void:
	if is_open and structure == chest:
		close()

## Chest grid click: transfer the clicked stack whole into the player's inventory.
func _on_cell_pressed(cell: Vector2i) -> void:
	if inventory == null or player == null:
		return
	var stack := inventory.stack_at_cell(cell)
	if stack != null:
		inventory.transfer_to(player.inventory, stack)

## Player grid click: transfer the clicked stack whole into the chest's inventory.
func _on_player_cell_pressed(cell: Vector2i) -> void:
	if inventory == null or player == null:
		return
	var stack := player.inventory.stack_at_cell(cell)
	if stack != null:
		player.inventory.transfer_to(inventory, stack)

func _on_player_inventory_changed(_inventory: Inventory) -> void:
	_refresh_player_capacity()

func _refresh_player_capacity() -> void:
	_player_capacity.text = player.inventory.describe_capacity() if player and player.inventory else ""

static func create(_player: Player = null) -> ChestGridInventoryPanel:
	var panel: ChestGridInventoryPanel = SCENE.instantiate()
	panel.player = _player
	return panel
