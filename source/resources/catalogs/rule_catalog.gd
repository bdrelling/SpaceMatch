class_name RuleCatalog
extends Catalog
## The catalog of [MatchRules] — named rule sets a match can run. The first entry is the active set the
## board uses (see [DebugConfig.match_rules]). Rule sets are hand-authored (the catalog has no directory,
## so [method regenerate] is a no-op); its code-built default is the standard SpaceMatch rules. The editor
## edits a set via the existing [MatchRulesView].

@export var rulesets: Array[MatchRules] = []

func entries() -> Array:
	return rulesets

func entry_title(entry: Resource) -> String:
	var index := rulesets.find(entry as MatchRules)
	return "Default rules" if index <= 0 else "Ruleset %d" % (index + 1)

func add_new() -> Resource:
	var rules := MatchRules.default()
	rulesets.append(rules)
	return rules

func remove_entry(entry: Resource) -> void:
	var rules := entry as MatchRules
	if rules != null:
		rulesets.erase(rules)

## The active rule set the board runs — the first entry, or null if the catalog is empty.
func active() -> MatchRules:
	return rulesets[0] if not rulesets.is_empty() else null

static func default() -> RuleCatalog:
	var catalog := RuleCatalog.new()
	catalog.catalog_name = "Rules"
	catalog.rulesets.append(MatchRules.default())
	return catalog
