class_name ResourceGrantRule
extends Rule
## Banks matched tiles into the mover's encounter resources — the default "a match of N tiles is worth N
## of that resource" rule, now plug-in and swappable. Fires on [constant MatchPhase.ON_CLEAR], once per
## cascade step. Only the kinds in [member kinds] bank here (the four stat tiles by default); scrap, damage
## and warp route through their own rules. The amount comes from the encounter's scoring formula via
## [method MatchRuleContext.reward_for] plus the mover's effective stat for that tile (a +4 Power matched on a
## 3-run banks 7 combat), so a starship's stats and a swapped formula both reshape every grant.

## The resources this rule banks into the mover's tally (combat / propulsion / science / defense by default).
@export var resources: Array[StarshipResource] = _default_resources()
## Relative spawn weight per resource in [member resources], index-aligned — how often each stat tile fills the
## board. The rule owns what it spawns, so dropping it takes these tiles off the board entirely.
@export var spawn_weights: PackedInt32Array = PackedInt32Array([20, 20, 20, 20])

# The default banked resources — the four stat tiles, in tile-kind order.
static func _default_resources() -> Array[StarshipResource]:
	return [
		preload("res://data/ability_resources/combat.tres"),
		preload("res://data/ability_resources/propulsion.tres"),
		preload("res://data/ability_resources/science.tres"),
		preload("res://data/ability_resources/defense.tres"),
	]

func _init() -> void:
	rule_name = &"resource_grant"
	phase = MatchPhase.ON_CLEAR

# The tiles this rule contributes to the board's spawn pool: each of its resources' tile kinds at the matching
# weight. The grid spawns by int kind, so the table is keyed by tile_kind.
func spawn_contribution() -> Dictionary:
	var table := {}
	for i: int in resources.size():
		var resource: StarshipResource = resources[i]
		if resource == null:
			continue
		var weight: int = spawn_weights[i] if i < spawn_weights.size() else 0
		table[resource.tile_kind] = maxi(0, weight)
	return table

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null:
		return
	var starship: EncounterStarshipState = match_context.encounter.starship_of(match_context.combatant)
	if starship == null:
		return
	for resource: StarshipResource in resources:
		if resource == null:
			continue
		var kind: int = resource.tile_kind
		var count: int = match_context.counts.get(kind, 0)
		if count <= 0:
			continue
		var reward: int = match_context.reward_for(count)
		# The tile's effective stat bonuses the haul: a match grants reward_for(N) + that stat. The stat only
		# ever adds (floored at 0) — it's extra mana, so a net-negative stat never penalizes a match.
		var stat: StarshipStat = Stats.for_tile(kind)
		if match_context.actor_stats != null and stat != null:
			reward += maxi(0, match_context.actor_stats.get_stat(stat))
		# Banks into the mover's tally, clamped to its capacity for this resource (unlimited by default).
		starship.add_resource(resource, reward)
		match_context.visuals.append({"type": "resource", "kind": kind, "amount": reward, "center": match_context.centers.get(kind, Vector2.ZERO)})
