class_name ClampStep
extends ModificationStep
## Bounds the change. [member maximum] caps it (Intangible = cap at 1); [member minimum] floors it. A negative
## [member maximum] means no cap.

@export var minimum: int = 0
@export var maximum: int = -1


func order() -> int:
	return 400


func modify(modification: Modification, _context: ResolutionContext) -> void:
	if maximum >= 0:
		modification.amount = mini(modification.amount, maximum)
	modification.amount = maxi(modification.amount, minimum)
