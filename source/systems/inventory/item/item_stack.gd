class_name ItemStack
extends Resource
## A quantity of a single item variant — the base [ItemBlueprint] it stacks, the variant
## [member tags], and a count. Doubles as authored data: recipes and inventory blueprints
## author these directly, and an [Inventory] copies them into its own live stacks.
##
## NOTE: NOT an example of the Blueprint pattern. ItemStack holds and reads its [ItemBlueprint]
## directly at runtime (shared, immutable type data) — it never copies a blueprint's fields onto
## itself and discards it the way apply_blueprint() types do. Don't reference ItemStack when
## modelling the Type+Blueprint pattern; use [ScrapHeap]/[ScrapHeapBlueprint] or
## armory/docs/godot/patterns/blueprint.md.

#region Properties

@export var item_blueprint: ItemBlueprint
@export var quantity: int = 1
## Variant tags layered over the base [member item_blueprint]. Variants exist only as
## id + tags — never as separate blueprints.
@export var tags: Array[Item.Tag] = []

## The variant this stack holds — base id plus [member tags].
var variant_id: ItemVariantId:
	get:
		return ItemVariantId.new(item_blueprint.id if item_blueprint != null else -1, tags)

## Name shown for this stack, including variant tags (see [method Item.tagged_name]).
var display_name: String:
	get:
		return Item.tagged_name(item_blueprint.name, tags) if item_blueprint != null else ""

#endregion

#region Methods

func add(amount: int) -> void:
	quantity += amount

func remove(amount: int) -> void:
	quantity = max(0, quantity - amount)

func can_merge(other: ItemStack) -> bool:
	if other == null or other.item_blueprint == null or item_blueprint == null:
		return false
	return variant_id.equals(other.variant_id)

## Combines another stack of the same item into this one. Returns false when the
## stacks hold different items.
func merge(other: ItemStack) -> bool:
	if not can_merge(other):
		return false

	add(other.quantity)
	return true

## Splits [param amount] off into a new stack, leaving the remainder here. Returns
## null when [param amount] is not a valid portion of this stack.
func split(amount: int) -> ItemStack:
	if amount <= 0 or amount >= quantity:
		return null

	remove(amount)
	return ItemStack.create(item_blueprint, amount, tags)

## Builds a world [Item] of this stack's variant — created from the base blueprint, then
## stamped with [member tags].
func create_item() -> Item:
	var item: Item = Item.create(item_blueprint)
	if item == null:
		return null
	for tag: Item.Tag in tags:
		item.add_tag(tag)
	return item

static func create(_item_blueprint: ItemBlueprint, _quantity: int = 1, _tags: Array[Item.Tag] = []) -> ItemStack:
	if not _item_blueprint:
		Log.error("ItemBlueprint required to create ItemStack")
		return null

	var stack := ItemStack.new()
	stack.item_blueprint = _item_blueprint
	stack.quantity = _quantity
	stack.tags = _tags.duplicate()
	return stack

#endregion
