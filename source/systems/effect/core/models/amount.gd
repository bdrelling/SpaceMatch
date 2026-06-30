class_name Amount
extends Resource
## How a numeric value for an [Action] is computed — a constant or read from a stat.

## The value this amount resolves to in [param context]. Subclasses override; the base yields nothing.
func evaluate(_context: ResolutionContext) -> int:
	return 0
