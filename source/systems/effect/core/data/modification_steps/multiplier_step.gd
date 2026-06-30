class_name MultiplierStep
extends ModificationStep
## Scales the change by [member factor], flooring the result. On a target's status it reads as Vulnerable
## ([code]factor > 1[/code]); on the source's status it reads as Weak / empower — the side is decided by which
## entity carries the status, not by the step.

@export var factor: float = 1.0


func order() -> int:
	return 100


func modify(modification: Modification, _context: ResolutionContext) -> void:
	modification.amount = floori(modification.amount * factor)
