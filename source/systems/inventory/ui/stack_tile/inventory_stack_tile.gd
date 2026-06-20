class_name InventoryStackTile
extends Control
## One stack rendered over its grid cells: footprint silhouette, item icon, and quantity.
## Pure visual — input routes through the owning [InventoryGridView].

const SCENE_PATH := "res://systems/inventory/ui/stack_tile/inventory_stack_tile.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## Plain white square shown when an item has no authored inventory_texture, so the blueprint's
## color still reads as a swatch.
static var _fallback_swatch: Texture2D = _make_fallback_swatch()

var stack: ItemStack

# Footprint cells in local space, already rotated by the stack's placement.
var _cells: Array[Vector2i] = []
var _cell_size: int = 48
var _cell_separation: int = 4

@onready var _icon: TextureRect = %Icon
@onready var _quantity: Label = %Quantity

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if stack == null or stack.item_blueprint == null:
		return
	var blueprint: ItemBlueprint = stack.item_blueprint
	var damaged: bool = stack.tags.has(Item.Tag.DAMAGED)
	_icon.texture = blueprint.inventory_texture if blueprint.inventory_texture != null else _fallback_swatch
	_icon.modulate = blueprint.color.darkened(0.45) if damaged else blueprint.color
	_quantity.text = str(stack.quantity)
	_quantity.visible = stack.quantity > 1
	queue_redraw()

func _draw() -> void:
	if stack == null or stack.item_blueprint == null:
		return
	var blueprint: ItemBlueprint = stack.item_blueprint
	var damaged: bool = stack.tags.has(Item.Tag.DAMAGED)
	var fill: Color = blueprint.color.darkened(0.75 if damaged else 0.6)
	fill.a = 1.0
	var border: Color = blueprint.color.darkened(0.45) if damaged else blueprint.color
	var pitch := _cell_size + _cell_separation
	for cell: Vector2i in _cells:
		var rect := Rect2(Vector2(cell.x * pitch, cell.y * pitch), Vector2(_cell_size, _cell_size))
		draw_rect(rect, fill)
		draw_rect(rect, border, false, 1.0)

static func _make_fallback_swatch() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

## Builds a tile sized and positioned over [param placement]'s cells; [param first_row]
## shifts it into the owning view's visible row range.
static func create(_stack: ItemStack, placement: StackPlacement, cell_size: int, cell_separation: int, first_row: int = 0) -> InventoryStackTile:
	var tile: InventoryStackTile = SCENE.instantiate()
	tile.stack = _stack
	tile._cell_size = cell_size
	tile._cell_separation = cell_separation
	tile._cells = GridGeometry.rotate_cells(_stack.item_blueprint.footprint_cells, placement.rotation_steps)
	var pitch := cell_size + cell_separation
	tile.position = Vector2(placement.anchor.x * pitch, (placement.anchor.y - first_row) * pitch)
	var bounds := Vector2i.ONE
	for cell: Vector2i in tile._cells:
		bounds = Vector2i(maxi(bounds.x, cell.x + 1), maxi(bounds.y, cell.y + 1))
	tile.size = Vector2(bounds.x * pitch - cell_separation, bounds.y * pitch - cell_separation)
	return tile
