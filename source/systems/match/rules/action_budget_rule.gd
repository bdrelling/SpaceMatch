class_name ActionBudgetRule
extends Rule
## Sets how many board moves the mover gets this turn, and what using an ability does to the turn. Fires on
## [constant MatchPhase.TURN_START], writing the budget onto the active combatant's [Combatant];
## the match spends it down as moves resolve and passes the turn once it's gone (see [MatchGame]). The
## default — one action, an ability ends the turn — reproduces the original "a move or an ability ends your
## turn" exactly. A starship overrides it by carrying its own [ActionBudgetRule] of the same [member
## Rule.rule_name], the same way a starship overrides any match rule.

## What using an ability does to the mover's turn.
enum AbilityTurnCost {
	ENDS_TURN,  ## The ability ends the turn outright (the original behavior).
	COSTS_ACTION,  ## The ability spends one action like a move; the turn ends only once the budget is gone.
	FREE,  ## The ability neither ends the turn nor spends an action (the mover keeps acting, gated by resources).
}

## Board moves the mover gets each turn. One is the original single-move turn.
@export var actions_per_turn: int = 1
## What using an ability does to the turn (see [enum AbilityTurnCost]).
@export var ability_turn_cost: AbilityTurnCost = AbilityTurnCost.ENDS_TURN

func _init() -> void:
	rule_name = &"action_budget"
	phase = MatchPhase.TURN_START

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null or match_context.combatant == null:
		return
	var starship: Combatant = match_context.combatant
	starship.actions_remaining = maxi(1, actions_per_turn)
	starship.ability_turn_cost = ability_turn_cost
