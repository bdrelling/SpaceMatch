class_name ScoringRule
extends Rule
## The match's scoring as a composable rule: maps a cleared match's tile count to its reward, owning the
## [ScoringFormula] and answering [method reward_for] itself — so the host and the grant rules ask the rule
## rather than reaching into a config field. Drop it from a ruleset and scoring falls back to one-to-one (a
## match of N is worth N). A ship can override it by name to rescore its own turn. The per-turn reward shift
## is a separate concern — see [OffsetScoringRule].

## How a match's tile count becomes its reward. One-to-one [ScoringFormula] by default; assign a
## [FibonacciScoringFormula] to make bigger matches pay off super-linearly.
@export var formula: ScoringFormula = ScoringFormula.new()

func _init() -> void:
	rule_name = &"scoring"

## The reward for a match of [param count] tiles, per the formula (one-to-one when the formula is unset).
func reward_for(count: int) -> int:
	return formula.reward_for(count) if formula != null else maxi(0, count)
