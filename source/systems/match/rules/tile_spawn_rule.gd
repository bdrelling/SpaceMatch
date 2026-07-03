class_name TileSpawnRule
extends Rule
## Drops one tile onto the board at a relative weight. The board's spawn distribution is every TileSpawnRule in
## play — the match's set plus the active starship's — composed into one pool by [method Ruleset.aggregate]. A
## match carries one per spawnable tile; a starship can bring its own (e.g. a warp tile that only its hull rolls)
## or, with [constant Rule.CombineMode.STACK], pile more weight onto a tile the match already spawns.
##
## Identity is the tile it spawns (see [method combine_key]), not a name — so two rules for the same tile collide
## and merge per [member Rule.combine_mode]: REPLACE retunes the weight, STACK adds to it. Spawning and rewarding
## are separate: this rule decides what drops, a [TileMatchRule] decides what a matched tile is worth.

## The tile this spawns — its [member Tile.kind] is the kind dropped.
@export var tile: Tile
## Relative spawn weight against every other tile in play. Zero never drops.
@export var weight: int = 10


# Identity for composition: this tile's kind under the spawn namespace, so two spawn rules for the same tile
# collide and merge — but a spawn rule never collides with a [TileMatchRule] for the same tile (which lives under
# its own namespace). A rule with no tile (or a non-board one) has no identity and never collides.
func combine_key() -> Variant:
	return StringName("tile_spawn:" + str(tile.kind)) if tile != null and tile.kind >= 0 else null


# STACK merge: this rule's weight plus the earlier same-tile rule's.
func stacked(earlier: Rule) -> Rule:
	var other := earlier as TileSpawnRule
	if other == null:
		return self
	var merged := duplicate() as TileSpawnRule
	merged.weight = other.weight + weight
	return merged


# This rule's slice of the board spawn pool: its tile's kind at its weight. The grid spawns by int kind, so the
# table is keyed by the tile's kind.
func spawn_contribution() -> Dictionary:
	if tile == null or tile.kind < 0:
		return {}
	return {tile.kind: maxi(0, weight)}
