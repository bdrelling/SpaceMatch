@tool
class_name TileCollisionSet
extends Resource
## Per-kind collision outlines for match tiles, traced from each kind's sprite alpha so the physics
## silhouette tracks the art without anyone hand-plotting points. Polygons are in unit cell-space
## (centred on the origin, the full tile spanning 1.0), so a consumer scales them by its on-screen cell.
##
## Re-bake from the inspector: select [code]tile_collision_set.tres[/code] and press
## [b]Bake From Tile Textures[/b]. It reads [MatchTile]'s sprite table and overwrites [member polygons],
## then saves the resource. Re-run it whenever the tile art changes.

## Outline per tile kind, index-aligned with [MatchTile]'s sprite table. Kinds without art are absent,
## leaving the consumer to fall back to its own shape.
@export var polygons: Array[PackedVector2Array] = []

## Opaque cutoff for the alpha trace (0–1) — pixels above this count as solid.
@export var alpha_threshold: float = 0.5
## Outline simplification in source pixels; larger drops more points for a coarser, cheaper silhouette.
@export var simplify_epsilon: float = 4.0

@export_tool_button("Bake From Tile Textures") var _bake_button: Callable = bake

## The traced outline for [param kind] in unit cell-space, or an empty array when the kind has no art.
func outline_for(kind: int) -> PackedVector2Array:
	if kind >= 0 and kind < polygons.size():
		return polygons[kind]
	return PackedVector2Array()

## Re-trace every tile sprite and persist the result. Editor-only (needs the imported textures).
func bake() -> void:
	polygons = MatchTile.bake_collision_outlines(alpha_threshold, simplify_epsilon)
	if resource_path.is_empty():
		push_warning("TileCollisionSet baked but not saved — assign a resource path first.")
		return
	var status: int = ResourceSaver.save(self)
	if status == OK:
		print("TileCollisionSet: baked %d outlines into %s" % [polygons.size(), resource_path])
	else:
		push_error("TileCollisionSet: failed to save %s (error %d)" % [resource_path, status])
