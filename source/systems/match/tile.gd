class_name Tile
extends Resource
## A match-3 board token: the visual identity of one tile kind (its glyph, colour and label), keyed by the int
## [member kind] the grid stores. A tile is not a resource — what a matched tile is worth is a [TileMatchRule]'s
## job, not the tile's. The renderer ([MatchTile]) reads these fields; nothing here knows about pools or abilities.

## Stable string identity for this tile (combat, propulsion, ...). Its own name, not a resource pointer; the UI
## resolves a cost's glyph by matching this against the resource's name, but what a match is worth stays a rule's.
@export var name: StringName
## The board tile kind this represents — the int the grid stores, and what [code]counts[/code], spawn weights and
## [method Stats.for_tile] all key off. Stable identity, ascending in [TileCatalog]; -1 means unassigned.
@export var kind: int = -1
## Display name for the tile (Combat, Propulsion, ...).
@export var label: String = ""
## Glyph / readout colour for the tile.
@export var color: Color = Color.WHITE
## Tile sprite; null means the tile is drawn procedurally (the damage starburst).
@export var texture: Texture2D
