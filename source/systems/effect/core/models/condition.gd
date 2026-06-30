class_name Condition
extends Resource
## Gates an [Effect] on game state. The effect's action only resolves when every condition holds.

## Whether this condition is satisfied in [param context]. The base always holds; subclasses tighten it.
## Condition targets are relational (self/enemy), so this stays synchronous — gating never prompts a choice.
func holds(_context: ResolutionContext) -> bool:
	return true
