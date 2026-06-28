class_name ClampStep
extends DamageStep
## Bounds the damage. [member maximum] caps a hit (Intangible = cap at 1); [member minimum] floors it. A
## negative [member maximum] means no cap.

@export var minimum: int = 0
@export var maximum: int = -1


func phase() -> Phase:
	return Phase.CLAMP


func modify(packet: DamagePacket, _context: ResolutionContext) -> void:
	if maximum >= 0:
		packet.amount = mini(packet.amount, maximum)
	packet.amount = maxi(packet.amount, minimum)
