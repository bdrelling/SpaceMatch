class_name OutgoingActionHook
extends Hook
## Raised on the entity that caused a change — the actor side ("when I deal damage, heal", ...). [member tag]
## mirrors the change's tag; empty matches any. The change's subject and magnitude come from the context
## ([member ResolutionContext.modification]).

## The change's tag. Empty matches any; set it to match one kind.
@export var tag: StringName
