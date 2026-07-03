class_name TileCatalog
extends Catalog
## The catalog of [Tile]s — every board token the match can drop (combat, propulsion, ..., damage). Directory-backed:
## it gathers every authored tile from [code]data/tiles/[/code]. A full catalog of the tile universe, read at runtime
## by the renderer ([MatchTile]) and the spawn/kind pickers; the tile→reward economy lives in the rules, not here.

const _DIRECTORY := "res://data/tiles"

@export var tiles: Array[Tile] = []


func entries() -> Array:
	return tiles


## Every board tile kind, ascending — each [Tile]'s [member Tile.kind] of 0 or more. The spawn pool and tile
## pickers iterate this instead of a fixed count, so authoring a new tile adds its kind automatically.
func tile_kinds() -> Array[int]:
	var kinds: Array[int] = []
	for tile: Tile in tiles:
		if tile != null and tile.kind >= 0:
			kinds.append(tile.kind)
	kinds.sort()
	return kinds


## The [Tile] for board [param kind], or null when none maps to it. Bridges the grid's int kind to its token.
func for_kind(kind: int) -> Tile:
	for tile: Tile in tiles:
		if tile != null and tile.kind == kind:
			return tile
	return null


## The [Tile] named [param tile_name] (its own identity), or null when none matches. The UI resolves a cost's
## glyph by the shared name; the tile→reward link stays a [TileMatchRule]'s.
func for_name(tile_name: StringName) -> Tile:
	for tile: Tile in tiles:
		if tile != null and tile.name == tile_name:
			return tile
	return null


func entry_title(entry: Resource) -> String:
	var tile := entry as Tile
	if tile == null or tile.label.is_empty():
		return "Tile"
	return tile.label


func add_new() -> Resource:
	var tile := Tile.new()
	tile.name = &"new_tile"
	tiles.append(tile)
	return tile


func remove_entry(entry: Resource) -> void:
	var tile := entry as Tile
	if tile != null:
		tiles.erase(tile)


func matches(entry: Resource) -> bool:
	return entry is Tile


static func default() -> TileCatalog:
	var catalog := TileCatalog.new()
	catalog.catalog_name = "Tiles"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
