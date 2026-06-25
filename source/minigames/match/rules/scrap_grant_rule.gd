class_name ScrapGrantRule
extends Rule
## Banks matched scrap tiles into the player's wallet (the nav-bar currency) — the opponent has no wallet,
## so only the player's matches pay out, though the popup shows on either turn. Fires on
## [constant MatchPhase.ON_CLEAR]. Amount comes from the scoring formula like every other grant.

## The scrap tile kind.
@export var kind: int = 4
## Relative spawn weight for the scrap tile — how often it fills the board. Drop this rule and scrap stops
## spawning entirely.
@export var spawn_weight: int = 10

func _init() -> void:
	rule_name = &"scrap_grant"
	phase = MatchPhase.ON_CLEAR

# The tile this rule contributes to the board's spawn pool: scrap at its weight.
func spawn_contribution() -> Dictionary:
	return {kind: maxi(0, spawn_weight)}

func apply(context: RuleContext) -> void:
	var ctx := context as MatchRuleContext
	if ctx == null or not ctx.counts.has(kind):
		return
	var count: int = ctx.counts[kind]
	var reward: int = ctx.reward_for(count)
	# Only the player banks scrap; the opponent has no wallet.
	if ctx.combatant == EncounterState.Combatant.PLAYER and ctx.wallet != null:
		ctx.wallet.earn(reward)
	ctx.visuals.append({"type": "resource", "kind": kind, "amount": reward, "center": ctx.centers.get(kind, Vector2.ZERO)})
