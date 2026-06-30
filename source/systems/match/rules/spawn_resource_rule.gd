class_name SpawnResourceRule
extends Rule
## Drops one resource's tile onto the board at a relative weight. The board's spawn distribution is every
## SpawnResourceRule in play — the match's set plus the active starship's — composed into one pool by
## [method Ruleset.aggregate]. A match carries one per spawnable resource; a starship can bring its own (e.g. a
## warp tile that only its hull rolls) or, with [constant Rule.CombineMode.STACK], pile more weight onto a
## resource the match already spawns.
##
## Identity is the resource it spawns (see [method combine_key]), not a name — so two rules for the same
## resource collide and merge per [member Rule.combine_mode]: REPLACE retunes the weight, STACK adds to it.
## Spawning and granting are separate now: this rule decides what drops, the grant rules decide what a matched
## tile is worth.

## The resource whose tile this spawns — its [member StarshipResource.id] is the tile kind dropped.
@export var resource: StarshipResource
## Relative spawn weight against every other resource in play. Zero never drops.
@export var weight: int = 10

# Identity for composition: the resource's tile kind, so two spawn rules for the same resource collide and
# merge. A rule with no resource (or a non-board one) has no identity and never collides.
func combine_key() -> Variant:
	return resource.id if resource != null and resource.id >= 0 else null

# STACK merge: this rule's weight plus the earlier same-resource rule's.
func stacked(earlier: Rule) -> Rule:
	var other := earlier as SpawnResourceRule
	if other == null:
		return self
	var merged := duplicate() as SpawnResourceRule
	merged.weight = other.weight + weight
	return merged

# This rule's slice of the board spawn pool: its resource's tile kind at its weight. The grid spawns by int
# kind, so the table is keyed by the resource's id.
func spawn_contribution() -> Dictionary:
	if resource == null or resource.id < 0:
		return {}
	return {resource.id: maxi(0, weight)}
