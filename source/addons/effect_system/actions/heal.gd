class_name Heal
extends Action
## Restores [member amount] to the target.

@export var amount: Amount


## Adds the evaluated amount to the target's vitality stat. Capped at [code]max_health[/code] when the stat
## block declares one, so healing cannot overfill.
func resolve(context: ResolutionContext, target: Entity) -> void:
	if target == null or target.current_stats == null:
		return
	var restored := amount.evaluate(context) if amount != null else 0
	var health := int(target.current_stats.get_stat(context.health_stat)) + restored
	if &"max_health" in target.current_stats.stat_names():
		health = mini(health, int(target.current_stats.get_stat(&"max_health")))
	target.current_stats.set_stat(context.health_stat, health)
