class_name WarpRule
extends Rule
## Matched warp tiles charge the shared warp meter for the mover — a 3-run is one bar, a 4-run two, a 5-run
## three (the longest straight warp run minus two; precomputed onto the context). Fires on
## [constant MatchPhase.ON_CLEAR]. In Campaign the opponent's warp instead drains the player's, handled by
## [method WarpMeter.add]. Emits a "warp" visual for the host to pop. How often the warp tile drops is
## a [TileSpawnRule]'s job; the host still only rolls it when a starship can warp (see
## [method MatchGame._warp_active]).

## The warp tile — its [member Tile.kind] is the warp kind (used to center the "warp" visual).
@export var tile: Tile = preload("res://data/tiles/warp.tres")


func _init() -> void:
	rule_name = &"warp"
	phase = MatchPhase.ON_CLEAR


func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null or match_context.warp_bars <= 0:
		return
	var encounter := match_context.encounter
	encounter.warp_meter.add(match_context.combatant == encounter.player, match_context.warp_bars)
	var center: Vector2 = match_context.centers.get(tile.kind, Vector2.ZERO) if tile != null else Vector2.ZERO
	match_context.visuals.append({"type": "warp", "bars": match_context.warp_bars, "center": center})
