class_name MatchRules
extends Resource
## Tunable, swappable rules for one match-3 encounter — the knobs that change how a board plays without
## touching its code. Author a `.tres` per encounter (or call [method default] for the standard
## SpaceMatch set) and hand it to [MatchMinigame] as [member MatchMinigame.rules]; each field is one
## rule the encounter can turn on, off, or retune. Holds the extra-turn threshold and the per-kind
## spawn weights today; more rules land here as they're designed.

## A straight run of at least this many tiles lets the mover take another turn instead of passing it.
## Zero disables the rule — every match hands the board to the next combatant.
@export var extra_turn_min_match: int = 0

## Relative spawn weight per [MatchTile] kind, index-aligned to kind order. Heavier kinds fill the board
## more often; a weight of 0 never spawns. Weights are relative — they needn't sum to anything. An empty
## array, or a kind past the array's end, falls back to weight 1 (uniform).
@export var spawn_weights: PackedInt32Array = PackedInt32Array()

## The standard SpaceMatch ruleset: a run of four or more grants another turn, and the spawn pool favors
## the four stat tiles while the anomaly is the rarest find.
static func default() -> MatchRules:
	var rules := MatchRules.new()
	rules.extra_turn_min_match = 4
	# Index-aligned to MatchTile kinds: combat / propulsion / science / defense (20 each — the common
	# stat tiles), scrap (10), anomaly (5 — rarest), damage (10).
	rules.spawn_weights = PackedInt32Array([20, 20, 20, 20, 10, 5, 10])
	return rules

## The weight to roll [param kind] with — its authored weight, clamped non-negative, or 1 when the kind
## has no entry (so an unconfigured pool spawns every kind uniformly).
func weight_for(kind: int) -> int:
	if kind < 0 or kind >= spawn_weights.size():
		return 1
	return maxi(0, spawn_weights[kind])
