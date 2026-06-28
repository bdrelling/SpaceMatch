class_name AbsorbStep
extends DamageStep
## Drains a depletable pool stat (Block, shields) to soak damage before it reaches vitality. Unlike flat
## mitigation this is stateful: what it absorbs is written back, so the pool shrinks and breaks. Overkill
## (damage beyond the pool) empties it and the remainder carries through.

@export var stat: StringName


func phase() -> Phase:
	return Phase.ABSORB


func modify(packet: DamagePacket, _context: ResolutionContext) -> void:
	if packet.target == null or packet.target.current_stats == null:
		return
	var pool := int(packet.target.current_stats.get_stat(stat))
	if pool <= 0:
		return
	var absorbed := mini(pool, packet.amount)
	packet.target.current_stats.set_stat(stat, pool - absorbed)
	packet.amount -= absorbed
