class_name ScrapGrantRule
extends Rule
## Banks matched scrap tiles into the player's wallet (the nav-bar currency) — the opponent has no wallet,
## so only the player's matches pay out, though the popup shows on either turn. Fires on
## [constant MatchPhase.ON_CLEAR]. Amount comes from the scoring formula like every other grant.

## The scrap resource — its [member StarshipResource.tile_kind] is the scrap tile.
@export var resource: StarshipResource = preload("res://data/ability_resources/scrap.tres")
## Relative spawn weight for the scrap tile — how often it fills the board. Drop this rule and scrap stops
## spawning entirely.
@export var spawn_weight: int = 10

func _init() -> void:
	rule_name = &"scrap_grant"
	phase = MatchPhase.ON_CLEAR

# The tile this rule contributes to the board's spawn pool: scrap at its weight.
func spawn_contribution() -> Dictionary:
	if resource == null:
		return {}
	return {resource.tile_kind: maxi(0, spawn_weight)}

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or resource == null:
		return
	var kind: int = resource.tile_kind
	if not match_context.counts.has(kind):
		return
	var count: int = match_context.counts[kind]
	var reward: int = match_context.reward_for(count)
	# Only the player banks scrap; the opponent has no wallet.
	if match_context.combatant == EncounterState.Combatant.PLAYER and match_context.wallet != null:
		match_context.wallet.earn(reward)
	match_context.visuals.append({"type": "resource", "kind": kind, "amount": reward, "center": match_context.centers.get(kind, Vector2.ZERO)})
