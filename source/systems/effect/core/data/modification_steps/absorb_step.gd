class_name AbsorbStep
extends ModificationStep
## Drains a depletable pool stat (Block, shields) to soak the change before it reaches the target stat. Unlike
## flat mitigation this is stateful: what it absorbs is written back, so the pool shrinks and breaks. Overkill
## (beyond the pool) empties it and the remainder carries through.

@export var stat: EntityStat


func order() -> int:
	return 300


func modify(modification: Modification, _context: ResolutionContext) -> void:
	if modification.target == null or modification.target.current_stats == null:
		return
	var pool := modification.target.current_stats.get_stat(stat)
	if pool <= 0:
		return
	var absorbed := mini(pool, modification.amount)
	modification.target.current_stats.set_stat(stat, pool - absorbed)
	modification.amount -= absorbed
