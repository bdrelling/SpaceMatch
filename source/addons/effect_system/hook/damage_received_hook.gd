class_name DamageReceivedHook
extends Hook
## Raised when the owning entity takes damage, carrying the hit's details.

@export var amount: int = 0
@export var damage_type: StringName
@export var attacker: Entity
