class_name ResourceGrantRule
extends Rule
## Banks matched tiles into the mover's encounter resources — the default "a match of N tiles is worth N
## of that resource" rule, now plug-in and swappable. Fires on [constant MatchPhase.ON_CLEAR], once per
## cascade step. Only the kinds in [member kinds] bank here (the four stat tiles by default); scrap, damage
## and warp route through their own rules. The amount comes from the encounter's scoring formula via
## [method MatchRuleContext.reward_for] plus the mover's effective stat for that tile (a +4 Power matched on a
## 3-run banks 7 combat), so a ship's stats and a swapped formula both reshape every grant.

## The tile kinds this rule banks into the mover's tally (combat / propulsion / science / defense by default).
@export var kinds: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
## Relative spawn weight per kind in [member kinds], index-aligned — how often each stat tile fills the board.
## The rule owns what it spawns, so dropping it takes these tiles off the board entirely.
@export var spawn_weights: PackedInt32Array = PackedInt32Array([20, 20, 20, 20])

func _init() -> void:
	rule_name = &"resource_grant"
	phase = MatchPhase.ON_CLEAR

# The tiles this rule contributes to the board's spawn pool: each of its kinds at the matching weight.
func spawn_contribution() -> Dictionary:
	var table := {}
	for i: int in kinds.size():
		var weight: int = spawn_weights[i] if i < spawn_weights.size() else 0
		table[kinds[i]] = maxi(0, weight)
	return table

func apply(context: RuleContext) -> void:
	var ctx := context as MatchRuleContext
	if ctx == null or ctx.encounter == null:
		return
	var ship: EncounterStarshipState = ctx.encounter.ship_of(ctx.combatant)
	if ship == null:
		return
	for kind: int in ctx.counts:
		if not kinds.has(kind):
			continue
		var count: int = ctx.counts[kind]
		var reward: int = ctx.reward_for(count)
		# The tile's effective stat bonuses the haul: a match grants reward_for(N) + that stat. The stat only
		# ever adds (floored at 0) — it's extra mana, so a net-negative stat never penalizes a match.
		var stat: int = Stat.for_tile(kind)
		if ctx.actor_stats != null and stat != -1:
			reward += maxi(0, ctx.actor_stats.value(stat))
		# Banks into the mover's tally, clamped to its capacity for this kind (unlimited by default).
		ship.add_resource(kind, reward)
		ctx.visuals.append({"type": "resource", "kind": kind, "amount": reward, "center": ctx.centers.get(kind, Vector2.ZERO)})
