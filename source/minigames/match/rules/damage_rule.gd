class_name DamageRule
extends Rule
## Matched damage tiles deplete the other combatant's health — the match reward plus the mover's effective
## DAMAGE stat (module-grid profile + temporary buffs, e.g. Target Lock) — and fly to the struck portrait.
## Fires on [constant MatchPhase.ON_CLEAR]. Emits a "damage" visual (the cells, target, dealt and result) for
## the host to animate; the hit lands here.

## The damage tile kind.
@export var kind: int = 6
## Relative spawn weight for the damage tile — how often it fills the board. Drop this rule and damage tiles
## stop spawning entirely.
@export var spawn_weight: int = 10

func _init() -> void:
	rule_name = &"damage"
	phase = MatchPhase.ON_CLEAR

# The tile this rule contributes to the board's spawn pool: damage at its weight.
func spawn_contribution() -> Dictionary:
	return {kind: maxi(0, spawn_weight)}

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null or match_context.damage_cells.is_empty():
		return
	var dealt: int = match_context.reward_for(match_context.damage_cells.size())
	if match_context.actor_stats != null:
		dealt += maxi(0, match_context.actor_stats.damage)  # effective DAMAGE bonuses the hit; only ever adds (floored at 0)
	var target: int = match_context.encounter.opponent_of(match_context.combatant)
	var result: int = match_context.encounter.deal_damage(target, dealt)
	match_context.visuals.append({"type": "damage", "cells": match_context.damage_cells, "target": target, "dealt": dealt, "result": result})
