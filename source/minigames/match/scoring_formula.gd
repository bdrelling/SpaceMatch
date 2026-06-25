class_name ScoringFormula
extends Resource
## Maps a match's tile count to its reward — the one knob that decides whether a bigger match pays off
## one-for-one or super-linearly. The base formula is one-to-one (a match of N is worth N); subclass and
## override [method reward_for] to reshape it (see [FibonacciScoringFormula]). Held by [MatchRules] and
## applied to every banked kind (the four stat tiles, scrap, damage). Built as a swappable [Resource] so
## scoring can later be overridden per kind or by player modifiers — the rules pick which formula a kind
## scores on, and the formula only ever answers "what is a match of this size worth".

## The reward for clearing [param quantity] tiles of a kind in one match. One-to-one by default; override
## to reshape. Never negative.
func reward_for(quantity: int) -> int:
	return maxi(0, quantity)
