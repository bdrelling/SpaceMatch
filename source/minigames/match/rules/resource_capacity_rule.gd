class_name ResourceCapacityRule
extends Rule
## Caps how much of each resource the mover can hold. Fires on [constant MatchPhase.TURN_START], writing the
## per-kind maximums onto the active combatant's [EncounterStarshipState]; banking then clamps to them (see
## [method EncounterStarshipState.add_resource]). Empty (or a zero slot) means unlimited — the default, so a
## fresh match banks without a ceiling. A starship overrides it by carrying its own rule of the same name.

## The most of each [MatchTile] kind the mover may hold, index-aligned to kind. Empty or a zero slot is
## unlimited; author only the kinds you want to cap (the four stat tiles, 0–3).
@export var maximums: PackedInt32Array = PackedInt32Array()

func _init() -> void:
	rule_name = &"resource_capacity"
	phase = MatchPhase.TURN_START

func apply(context: RuleContext) -> void:
	var match_context := context as MatchRuleContext
	if match_context == null or match_context.encounter == null or match_context.combatant < 0:
		return
	var starship: EncounterStarshipState = match_context.encounter.starship_of(match_context.combatant)
	if starship == null:
		return
	starship.set_resource_maximums(maximums)
