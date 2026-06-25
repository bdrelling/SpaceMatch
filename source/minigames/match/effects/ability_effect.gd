class_name AbilityEffect
extends Resource
## One thing using a [MatchAbility] does — deal damage, raise a shield, arm a dodge, drain resources, and so
## on. An ability holds a list of these (see [member MatchAbility.effects]) and runs them in order, so an
## ability can do several things or just one. Each subclass carries only the parameters its own effect needs;
## there is deliberately no shared "magnitude", because not every effect has an amount (a [DodgeEffect] has
## none, a [DisableEffect] counts turns). Subclasses live in [code]effects/[/code]; the board applies each by
## type — see [code]match.gd[/code]'s [code]_apply_effect[/code].

## A short, human description of this effect for the ability tooltip — e.g. "Deal 5 damage". Overridden per
## subclass; the base returns an empty string.
func describe() -> String:
	return ""
