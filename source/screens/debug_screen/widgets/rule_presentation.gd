class_name RulePresentation
extends RefCounted
## Presentation-only helpers for showing a [Rule] — its display name and the resource colour it acts on.
## Shared by the editable Match Rules page ([MatchRulesView]) and the read-only player [RulesView] so the
## two stay in step. Pure functions, no state.

## Title-cases a rule's identifier ("resource_grant" → "Resource Grant"); "Rule" if it has none.
static func display_name(rule: Rule) -> String:
	var identifier := String(rule.rule_name)
	return identifier.capitalize() if not identifier.is_empty() else "Rule"

## The resource colour a rule acts on (from its "resource", or first of "resources"), else white for
## independent rules.
static func accent_for(rule: Rule) -> Color:
	var kind := kind_of(rule)
	return MatchTile.color_of(kind) if kind >= 0 else Color.WHITE

## The tile kind a rule acts on (its "resource", or first of "resources"), or -1 if it isn't resource-bound.
static func kind_of(rule: Rule) -> int:
	var single: Variant = rule.get("resource")
	if single is StarshipResource:
		var resource: StarshipResource = single
		return resource.id
	var many: Variant = rule.get("resources")
	if many is Array:
		var resources: Array = many
		for entry: Variant in resources:
			if entry is StarshipResource:
				var resource: StarshipResource = entry
				return resource.id
	return -1
