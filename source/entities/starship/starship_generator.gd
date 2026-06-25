class_name StarshipGenerator
extends RefCounted
## Stateless factory: builds a [StarshipState] from a [StarshipBlueprint], using a [ModuleGridGenerator]
## for its module grid.

static func generate(blueprint: StarshipBlueprint) -> StarshipState:
	var starship := StarshipState.new()
	if blueprint == null:
		return starship
	starship.name = blueprint.name
	# Copy the base stat block so each generated ship owns its own (a shared exported default would let two
	# ships' buffs bleed together). Null authoring means a blank block — no intrinsic stats.
	starship.stats = blueprint.stats.duplicate() if blueprint.stats != null else StatBlock.new()
	starship.module_grid = ModuleGridGenerator.generate(blueprint.module_grid)
	# Rules and abilities are the ship's, not the match's: a hull authors its own, else it gets the standard
	# kit (a match-4 extra turn, the five stat abilities). Modules layer more on at match time.
	starship.ruleset = blueprint.ruleset if blueprint.ruleset != null else _standard_ruleset()
	starship.abilities = blueprint.abilities.duplicate() if not blueprint.abilities.is_empty() else _standard_abilities()
	# A fresh ship starts at full hull — its max is derived from its stats and modules, so this is known now.
	starship.health = starship.max_health()
	return starship

## The baseline hull kit: a match of four or more keeps the board (the extra-turn rule, now ship-owned).
static func _standard_ruleset() -> Ruleset:
	var ruleset := Ruleset.new()
	var extra_turn := ExtraTurnRule.new()
	extra_turn.min_match = 4
	ruleset.add(extra_turn)
	return ruleset

## The baseline hull abilities: one per stat tile (red/yellow/green/blue), plus a Disruptor that spends green.
##   Red — Target Lock: +1 to your tile damage for the rest of the encounter (stacks).
##   Yellow — Evasive Maneuvers: dodge the next attack (cheap).
##   Green — Siphon: drain 2 of each of the opponent's resources.
##   Blue — Shields: gain 10 shield (absorbed before health).
##   Green — Disruptor: disable one of the opponent's modules for 3 turns.
static func _standard_abilities() -> Array[MatchAbility]:
	return [
		MatchAbility.make("Target Lock", AbilityCost.make(0, 10), DamageBuffEffect.make(1)),
		MatchAbility.make("Evasive Maneuvers", AbilityCost.make(1, 5), DodgeEffect.make()),
		MatchAbility.make("Siphon", AbilityCost.make(2, 10), DrainEffect.make(2)),
		MatchAbility.make("Shields", AbilityCost.make(3, 10), ShieldEffect.make(10)),
		MatchAbility.make("Disruptor", AbilityCost.make(2, 12), DisableEffect.make(3)),
	]
