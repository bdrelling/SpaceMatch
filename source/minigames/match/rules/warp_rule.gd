class_name WarpRule
extends Rule
## Matched warp tiles charge the shared warp meter for the mover — a 3-run is one bar, a 4-run two, a 5-run
## three (the longest straight warp run minus two; precomputed onto the context). Fires on
## [constant MatchPhase.ON_CLEAR]. In Campaign the opponent's warp instead drains the player's, handled by
## [method EncounterState.add_warp]. Emits a "warp" visual for the host to pop.

## The warp tile kind.
@export var kind: int = 5
## Relative spawn weight for the warp tile — how often it fills the board (rarest by default). The board only
## actually rolls warp tiles when a ship can warp; drop this rule and warp stops entirely.
@export var spawn_weight: int = 2

func _init() -> void:
	rule_name = &"warp"
	phase = MatchPhase.ON_CLEAR

# The tile this rule contributes to the board's spawn pool: warp at its weight. The host still gates this on a
# ship actually having warp capacity (see [method MatchMinigame._warp_active]).
func spawn_contribution() -> Dictionary:
	return {kind: maxi(0, spawn_weight)}

func apply(context: RuleContext) -> void:
	var ctx := context as MatchRuleContext
	if ctx == null or ctx.encounter == null or ctx.warp_bars <= 0:
		return
	ctx.encounter.add_warp(ctx.combatant, ctx.warp_bars)
	ctx.visuals.append({"type": "warp", "bars": ctx.warp_bars, "center": ctx.centers.get(kind, Vector2.ZERO)})
