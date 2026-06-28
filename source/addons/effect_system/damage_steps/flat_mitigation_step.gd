class_name FlatMitigationStep
extends DamageStep
## Subtracts the target's [member stat] (e.g. armor) from the damage, never taking it below zero. Reads the
## value but does not consume it — armor mitigates every hit at full strength.

@export var stat: StringName


func phase() -> Phase:
	return Phase.MITIGATE


func modify(packet: DamagePacket, _context: ResolutionContext) -> void:
	if packet.target == null or packet.target.current_stats == null:
		return
	var defense := int(packet.target.current_stats.get_stat(stat))
	packet.amount = max(0, packet.amount - defense)
