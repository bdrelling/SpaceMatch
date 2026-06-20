class_name LandingPadState
extends Resource
## One landing pad. Empty unless a ship has docked: [member occupant] holds it and
## [member time_occupied] counts how long it has been there.

@export var occupant: ShipState = null
@export var time_occupied: float = 0.0

var is_occupied: bool:
	get: return occupant != null and time_occupied > 0.0
