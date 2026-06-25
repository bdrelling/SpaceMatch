class_name RulePresentation
extends RefCounted
## Presentation-only helpers for showing a [Rule] — its display name and the resource colour it acts on.
## Shared by the editable Match Rules page ([MatchRulesView]) and the read-only player [RulesView] so the
## two stay in step. Pure functions, no state.

## Title-cases a rule's identifier ("resource_grant" → "Resource Grant"); "Rule" if it has none.
static func display_name(rule: Rule) -> String:
	var identifier := String(rule.rule_name)
	return identifier.capitalize() if not identifier.is_empty() else "Rule"

## The resource colour a rule acts on (from its "kind", or first of "kinds"), else white for independent rules.
static func accent_for(rule: Rule) -> Color:
	var kind := kind_of(rule)
	return MatchTile.color_of(kind) if kind >= 0 else Color.WHITE

## The tile kind a rule acts on (its "kind", or first of "kinds"), or -1 if it isn't resource-bound.
static func kind_of(rule: Rule) -> int:
	var single: Variant = rule.get("kind")
	if typeof(single) == TYPE_INT:
		var value: int = single
		return value
	var many: Variant = rule.get("kinds")
	if typeof(many) == TYPE_PACKED_INT32_ARRAY:
		var kinds: PackedInt32Array = many
		if kinds.size() > 0:
			return kinds[0]
	return -1
