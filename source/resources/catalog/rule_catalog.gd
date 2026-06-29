class_name RuleCatalog
extends Catalog
## The catalog of game modes — named [Ruleset]s a match can run. The first entry is the active mode the board
## uses (see [DebugConfig.match_ruleset]). Modes are hand-authored `.tres` (the catalog has no directory, so
## [method regenerate] is a no-op); its built-in default is the standard SpaceMatch ruleset. The editor edits a
## mode via [MatchRulesView].

## The authored standard mode — loaded fresh so a default catalog (and tests) get an independent copy.
const DEFAULT_PATH := "res://data/rulesets/default.tres"

@export var rulesets: Array[Ruleset] = []

func entries() -> Array:
	return rulesets

func entry_title(entry: Resource) -> String:
	var index := rulesets.find(entry as Ruleset)
	return "Default rules" if index <= 0 else "Ruleset %d" % (index + 1)

func add_new() -> Resource:
	var mode := default_ruleset()
	rulesets.append(mode)
	return mode

func remove_entry(entry: Resource) -> void:
	var mode := entry as Ruleset
	if mode != null:
		rulesets.erase(mode)

## The active mode the board runs — the first entry, or null if the catalog is empty.
func active() -> Ruleset:
	return rulesets[0] if not rulesets.is_empty() else null

## A fresh deep copy of the standard SpaceMatch ruleset authored in [code]default.tres[/code], so callers (and
## tests) edit independent instances. The one place the standard set is sourced now that it's authored, not code.
static func default_ruleset() -> Ruleset:
	var authored := load(DEFAULT_PATH) as Ruleset
	return authored.duplicate(true) if authored != null else Ruleset.new()

static func default() -> RuleCatalog:
	var catalog := RuleCatalog.new()
	catalog.catalog_name = "Rules"
	catalog.rulesets.append(default_ruleset())
	return catalog
