class_name FlatMitigationStep
extends ModificationStep
## Subtracts the target's [member stat] (e.g. armor) from the change, never taking it below zero. Reads the
## value but does not consume it — armor mitigates every hit at full strength.

@export var stat: EntityStat


func order() -> int:
	return 200


func modify(modification: Modification, _context: ResolutionContext) -> void:
	if modification.target == null or modification.target.current_stats == null:
		return
	var defense := modification.target.current_stats.get_stat(stat)
	modification.amount = max(0, modification.amount - defense)
