class_name ScrapHeapBlueprint
extends Resource
## Authored data for a [ScrapHeap] — how many times it can be salvaged, what it drops,
## and how it collapses. Copied onto the heap at apply time; never read at runtime.

## Number of times the heap can be salvaged before it collapses. Debug heaps use a very
## high value (e.g. 1000) so they can be hammered while testing; field heaps use 1–3.
@export var max_interactions: int = 3
## Weighted pool the heap rolls on each salvage. Shared, read-only type data, so a single
## table can back many heaps.
@export var loot_table: LootTable
## Model scale the heap shrinks to when it collapses. Low height reads as a flattened pile.
@export var collapse_scale: Vector3 = Vector3(0.7, 0.05, 0.7)
