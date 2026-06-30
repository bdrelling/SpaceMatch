class_name StarshipResource
extends AbilityResource
## A SpaceMatch resource — an [AbilityResource] that also carries its match-tile representation. Resources map 1:1
## to board tile kinds, so the resource owns the tile's look (label, color, sprite) rather than a separate tile
## object. The grid stores an int tile kind; this binds that kind to the resource and its art.

## The [MatchTile] kind this resource is banked from — its index on the board. -1 means it is not a board tile.
@export var tile_kind: int = -1
## Display name for the resource and its tile (Combat, Propulsion, ...).
@export var label: String = ""
## Glyph / HUD color for the tile.
@export var color: Color = Color.WHITE
## Tile sprite; null means the tile is drawn procedurally (the damage starburst).
@export var texture: Texture2D
