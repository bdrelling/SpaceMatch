class_name DamageRule
extends Rule
## Matched damage tiles deplete the other combatant's health — the match reward plus the mover's effective
## DAMAGE stat (module-grid profile + temporary buffs, e.g. Target Lock) — and fly to the struck portrait.
## Fires on [constant MatchPhase.ON_CLEAR]. Emits a "damage" visual (the cells, target, dealt and result) for
## the host to animate; the hit lands here. How often the damage tile drops is a [SpawnResourceRule]'s job.

## The damage resource — its [member StarshipResource.id] is the damage tile.
@export var resource: StarshipResource = preload("res://data/ability_resources/damage.tres")

func _init() -> void:
	rule_name = &"damage"
	phase = MatchPhase.ON_CLEAR

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null or match_context.damage_cells.is_empty():
		return
	var dealt: int = match_context.reward_for(match_context.damage_cells.size())
	if match_context.actor_stats != null:
		dealt += maxi(0, match_context.actor_stats.weapons)  # effective Weapons bonuses the hit; only ever adds (floored at 0)
	var target: Combatant = match_context.encounter.opponent_of(match_context.combatant)
	var result: int = match_context.encounter.deal_damage(target, dealt)
	match_context.visuals.append({"type": "damage", "cells": match_context.damage_cells, "target": target, "dealt": dealt, "result": result})
