class_name RuleCatalog
extends Catalog
## The catalog of named [Ruleset]s — every authored ruleset under [code]data/rulesets/[/code]. Like the other
## catalogs it is directory-backed: [method regenerate] gathers every [Ruleset] in that folder. [method active]
## is the board's standard fallback — the ruleset authored in [code]default.tres[/code] — pinned by path so the
## scan order can't change which one the board runs. The editor edits a ruleset via [MatchRulesView].

const _DIRECTORY := "res://data/rulesets"

## The authored standard ruleset — the one [method active] returns, and the independent copy [method default_ruleset] hands out.
const DEFAULT_PATH := "res://data/rulesets/default.tres"

@export var rulesets: Array[Ruleset] = []

func entries() -> Array:
	return rulesets

func entry_title(entry: Resource) -> String:
	var ruleset := entry as Ruleset
	if ruleset == null:
		return "Ruleset"
	if not ruleset.resource_path.is_empty():
		return ruleset.resource_path.get_file().get_basename().capitalize()
	return "Ruleset"

func matches(entry: Resource) -> bool:
	return entry is Ruleset

func add_new() -> Resource:
	var mode := default_ruleset()
	rulesets.append(mode)
	return mode

func remove_entry(entry: Resource) -> void:
	var mode := entry as Ruleset
	if mode != null:
		rulesets.erase(mode)

## The standard ruleset the board runs — the one authored in [code]default.tres[/code], found by path so the
## scan order doesn't matter. Falls back to the first entry, then a fresh standard set, if it isn't present.
func active() -> Ruleset:
	for ruleset: Ruleset in rulesets:
		if ruleset != null and ruleset.resource_path == DEFAULT_PATH:
			return ruleset
	return rulesets[0] if not rulesets.is_empty() else default_ruleset()

## A fresh deep copy of the standard SpaceMatch ruleset authored in [code]default.tres[/code], so callers (and
## tests) edit independent instances. The one place the standard set is sourced now that it's authored, not code.
static func default_ruleset() -> Ruleset:
	var authored := load(DEFAULT_PATH) as Ruleset
	return authored.duplicate(true) if authored != null else Ruleset.new()

static func default() -> RuleCatalog:
	var catalog := RuleCatalog.new()
	catalog.catalog_name = "Rules"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
