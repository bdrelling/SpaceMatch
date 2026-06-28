class_name DamagePipeline
extends RefCounted
## Runs a [DamagePacket] through every [DamageStep] the source and target contribute, in a fixed phase
## order, and returns the final amount to apply. Centralising the order here is the "do it right up front"
## move: [DealDamage] and any other source of damage (reflect, status ticks) resolve through the same
## pipeline, so a hit is mitigated identically no matter who launched it.
##
## Order within a hit:
## [codeblock]
## for each phase in AMPLIFY, MITIGATE, ABSORB, CLAMP:
##     apply the source's steps in that phase   # attacker-side (Weak, empower)
##     apply the target's steps in that phase   # defender-side (Vulnerable, armor, Block)
## floor the result at zero
## [/codeblock]

## Transforms [param packet] in place and returns its final, non-negative amount.
static func resolve(packet: DamagePacket, context: ResolutionContext) -> int:
	for phase in [DamageStep.Phase.AMPLIFY, DamageStep.Phase.MITIGATE, DamageStep.Phase.ABSORB, DamageStep.Phase.CLAMP]:
		_apply_phase(packet.source, phase, packet, context)
		_apply_phase(packet.target, phase, packet, context)
	packet.amount = maxi(0, packet.amount)
	return packet.amount


## Applies every step on [param owner]'s active statuses that belongs to [param phase], in status order.
static func _apply_phase(owner: Entity, phase: DamageStep.Phase, packet: DamagePacket, context: ResolutionContext) -> void:
	if owner == null:
		return
	for stack in owner.statuses:
		if stack.status == null:
			continue
		for step in stack.status.damage_steps:
			if step.phase() == phase:
				step.modify(packet, context)
