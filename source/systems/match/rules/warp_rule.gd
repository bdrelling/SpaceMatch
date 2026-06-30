class_name WarpRule
extends Rule
## Matched warp tiles charge the shared warp meter for the mover — a 3-run is one bar, a 4-run two, a 5-run
## three (the longest straight warp run minus two; precomputed onto the context). Fires on
## [constant MatchPhase.ON_CLEAR]. In Campaign the opponent's warp instead drains the player's, handled by
## [method EncounterState.add_warp]. Emits a "warp" visual for the host to pop.

## The warp resource — its [member StarshipResource.tile_kind] is the warp tile.
@export var resource: StarshipResource = preload("res://data/ability_resources/warp.tres")
## Relative spawn weight for the warp tile — how often it fills the board (rarest by default). The board only
## actually rolls warp tiles when a starship can warp; drop this rule and warp stops entirely.
@export var spawn_weight: int = 2

func _init() -> void:
	rule_name = &"warp"
	phase = MatchPhase.ON_CLEAR

# The tile this rule contributes to the board's spawn pool: warp at its weight. The host still gates this on a
# starship actually having warp capacity (see [method MatchGame._warp_active]).
func spawn_contribution() -> Dictionary:
	if resource == null:
		return {}
	return {resource.tile_kind: maxi(0, spawn_weight)}

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null or match_context.warp_bars <= 0:
		return
	match_context.encounter.add_warp(match_context.combatant, match_context.warp_bars)
	var center: Vector2 = match_context.centers.get(resource.tile_kind, Vector2.ZERO) if resource != null else Vector2.ZERO
	match_context.visuals.append({"type": "warp", "bars": match_context.warp_bars, "center": center})
