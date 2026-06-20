class_name LootTable
extends Resource
## A typed facade over a [WeightedCollection] of [ItemBlueprint]s: [method roll] picks one item by
## weight. The generic collection ([member _items]) is an implementation detail — callers go
## through [method roll], which is where the [ItemBlueprint] type is enforced. Shared, immutable.

## The wrapped weighted pool; its entries' values are [ItemBlueprint]s. Kept internal so callers
## depend on [method roll], not on the generic collection.
@export var _items: WeightedCollection

## Returns a random [ItemBlueprint] chosen by weight, or null when the table is empty / unset.
func roll() -> ItemBlueprint:
	return _items.pick() as ItemBlueprint if _items != null else null
