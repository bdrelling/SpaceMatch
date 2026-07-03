class_name TileMatchRule
extends Rule
## Banks a matched tile into the mover's encounter resources — the plug-in "a match of N of this tile is worth N
## of that resource" rule. One instance per rewarding tile: it owns the tile→reward link that used to ride on the
## resource's id, so the tile and the resource stay decoupled (a new rewarding tile is just another instance).
## Fires on [constant MatchPhase.ON_CLEAR], once per cascade step. The amount is the encounter's scoring formula
## (via [method MatchRuleContext.reward_for]) plus the mover's effective stat for the tile (a +4 Power on a 3-run
## banks 7 combat), so a starship's stats and a swapped formula both reshape every grant. What drops on the board
## is a [TileSpawnRule]'s job, not this rule's — spawning and rewarding are separate concerns.

## The tile this rewards — its [member Tile.kind] is what gets counted and its stat bonuses the haul.
@export var tile: Tile
## The resource a match of [member tile] banks into the mover's pools.
@export var reward: AbilityResource


func _init() -> void:
	rule_name = &"tile_match"
	phase = MatchPhase.ON_CLEAR


## The resource a matched tile of [param kind] banks — the enabled [TileMatchRule] for that kind in [param
## ruleset]'s resolved set, or null when none rewards it. The single kind->resource map now the tile no longer
## owns a resource; the readouts and the stalemate split resolve their rewards through it.
static func reward_for_kind(ruleset: Ruleset, kind: int) -> AbilityResource:
	if ruleset == null:
		return null
	for rule: Rule in ruleset.resolved():
		var match_rule := rule as TileMatchRule
		if match_rule != null and match_rule.enabled and match_rule.tile != null and match_rule.tile.kind == kind:
			return match_rule.reward
	return null


# Identity for composition: this tile's kind under the match namespace, so a starship rule for the same tile
# replaces (or stacks onto) the match's, and two rewards never both fire for one tile — but a reward rule never
# collides with a [TileSpawnRule] for the same tile (which lives under its own namespace).
func combine_key() -> Variant:
	return StringName("tile_match:" + str(tile.kind)) if tile != null and tile.kind >= 0 else null


func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null or tile == null or reward == null:
		return
	var starship: Combatant = match_context.combatant
	if starship == null:
		return
	var kind: int = tile.kind
	var count: int = match_context.counts.get(kind, 0)
	if count <= 0:
		return
	var amount: int = match_context.reward_for(count)
	# The tile's effective stat bonuses the haul: a match grants reward_for(N) + that stat. The stat only ever adds
	# (floored at 0) — it's extra mana, so a net-negative stat never penalizes a match.
	var stat: StarshipStat = Stats.for_tile(kind)
	if match_context.actor_stats != null and stat != null:
		amount += maxi(0, match_context.actor_stats.get_stat(stat))
	# Banks into the mover's pools through the engine's ResourceEngine, clamped to each pool's capacity (mirrored
	# from the combatant's per-kind maximums; unlimited by default).
	ResourceEngine.grant(starship, reward, amount)
	match_context.visuals.append({"type": "resource", "kind": kind, "amount": amount, "center": match_context.centers.get(kind, Vector2.ZERO)})
