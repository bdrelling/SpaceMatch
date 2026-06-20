class_name ItemBlueprint
extends Resource
## Static data for an item type — its identity and presentation. One shared resource per type:
## variants are never separate blueprints; an [Item] or [ItemStack] layers [enum Item.Tag]s
## over this same base.

@export var id: int = -1
@export var name: String
@export var category: Item.Category = Item.Category.SCRAP
@export var world_mesh: Mesh
@export var inventory_texture: Texture2D
@export var color: Color = Color.WHITE

## Weight of a single unit, counted by [WeightCapacityRule] inventories. 0 means weightless.
@export var weight: float = 0.0

## Most units a single stack holds. 0 means unbounded.
@export var max_stack_size: int = 0

## Grid cells occupied in a [GridCapacityRule] inventory, as offsets from the anchor cell.
@export var footprint_cells: Array[Vector2i] = [Vector2i.ZERO]
