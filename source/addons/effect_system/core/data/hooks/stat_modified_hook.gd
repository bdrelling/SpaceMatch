class_name StatModifiedHook
extends Hook
## Raised on the entity whose stat just changed — the generic stat-change event a reaction keys off (reflect a
## hit, take damage when healed, ...). [member tag] mirrors the change's tag ("damage", "heal", ...); leave it
## empty to react to any stat change, or set it to react to one kind. Who caused the change and how much it was
## come from the context ([member ResolutionContext.instigator] and [member ResolutionContext.modification]).

## The change's tag. Empty matches any stat change; set it to match one kind.
@export var tag: StringName
