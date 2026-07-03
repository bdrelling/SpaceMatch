class_name ScrapGrantRule
extends Rule
## Banks matched scrap tiles into the player's wallet (the nav-bar currency) — the opponent has no wallet,
## so only the player's matches pay out, though the popup shows on either turn. Fires on
## [constant MatchPhase.ON_CLEAR]. Amount comes from the scoring formula like every other grant. How often scrap
## drops is a [TileSpawnRule]'s job, not this rule's.

## The scrap tile — its [member Tile.kind] is the scrap kind this banks.
@export var tile: Tile = preload("res://data/tiles/scrap.tres")


func _init() -> void:
	rule_name = &"scrap_grant"
	phase = MatchPhase.ON_CLEAR


func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or tile == null:
		return
	var kind: int = tile.kind
	if not match_context.counts.has(kind):
		return
	var count: int = match_context.counts[kind]
	var reward: int = match_context.reward_for(count)
	# Only the player banks scrap; the opponent has no wallet.
	var is_player: bool = match_context.encounter != null and match_context.combatant == match_context.encounter.player
	if is_player and match_context.wallet != null:
		match_context.wallet.earn(reward)
	match_context.visuals.append({"type": "resource", "kind": kind, "amount": reward, "center": match_context.centers.get(kind, Vector2.ZERO)})
