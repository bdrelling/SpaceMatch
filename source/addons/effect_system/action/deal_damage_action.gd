class_name DealDamageAction
extends Action
## Deals [member amount] damage of [member damage_type] to the target.

@export var amount: Amount
@export var damage_type: StringName


## Builds a [DamagePacket], runs it through the [DamagePipeline], and subtracts the final amount from the
## target's vitality stat (floored at zero).
func resolve(context: ResolutionContext, target: Entity) -> void:
	if target == null or target.current_stats == null:
		return
	var packet := DamagePacket.new()
	packet.source = context.source
	packet.target = target
	packet.amount = amount.evaluate(context) if amount != null else 0
	packet.damage_type = damage_type
	var final_amount := DamagePipeline.resolve(packet, context)
	var health := int(target.current_stats.get_stat(context.health_stat))
	target.current_stats.set_stat(context.health_stat, maxi(0, health - final_amount))
