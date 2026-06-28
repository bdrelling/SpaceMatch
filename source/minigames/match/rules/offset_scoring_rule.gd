class_name OffsetScoringRule
extends Rule
## Shifts a match's reward down by a fixed amount: a match of N banks N minus [member offset] (floored at
## zero). Fires on [constant MatchPhase.TURN_START], writing the offset onto the active combatant's
## [EncounterStarshipState]; the grant rules read it back through [method MatchRuleContext.reward_for]. Zero —
## the default — leaves scoring one-to-one (a match of N banks N). A starship overrides it by name.

## Subtracted from every match's reward this turn (floored at zero). An offset of two turns a match-3 into a
## 1, a match-7 into a 5 — the banked amount becomes the resource a turn affords, spent on abilities.
@export var offset: int = 0

func _init() -> void:
	rule_name = &"scoring_offset"
	phase = MatchPhase.TURN_START

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null or match_context.combatant < 0:
		return
	var starship: EncounterStarshipState = match_context.encounter.starship_of(match_context.combatant)
	if starship == null:
		return
	starship.score_offset = maxi(0, offset)
