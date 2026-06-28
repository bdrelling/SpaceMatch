class_name MultiplierStep
extends DamageStep
## Scales the damage by [member factor], flooring the result. On a target's status it reads as Vulnerable
## ([code]factor > 1[/code]); on the source's status it reads as Weak / empower — the side is decided by
## which entity carries the status, not by the step.

@export var factor: float = 1.0


func phase() -> Phase:
	return Phase.AMPLIFY


func modify(packet: DamagePacket, _context: ResolutionContext) -> void:
	packet.amount = int(floor(packet.amount * factor))
