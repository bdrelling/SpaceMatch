class_name RulePresentation
extends RefCounted
## Presentation-only helpers for showing a [Rule] — its display name and the tile colour it acts on.
## Shared by the editable Match Rules page ([MatchRulesView]) and the read-only player [RulesView] so the
## two stay in step. Pure functions, no state.


## Title-cases a rule's identifier ("tile_match" → "Tile Match"); "Rule" if it has none.
static func display_name(rule: Rule) -> String:
	var identifier := String(rule.rule_name)
	return identifier.capitalize() if not identifier.is_empty() else "Rule"


## The tile colour a rule acts on (from its "tile"), else white for independent rules.
static func accent_for(rule: Rule) -> Color:
	var kind := kind_of(rule)
	return MatchTile.color_of(kind) if kind >= 0 else Color.WHITE


## The tile kind a rule acts on (its "tile"), or -1 if it isn't tile-bound.
static func kind_of(rule: Rule) -> int:
	var tile_value: Variant = rule.get("tile")
	if tile_value is Tile:
		var tile: Tile = tile_value
		return tile.kind
	return -1
