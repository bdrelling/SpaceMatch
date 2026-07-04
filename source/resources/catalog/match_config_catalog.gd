class_name MatchConfigCatalog
extends Catalog
## The catalog of named [MatchConfig]s — every authored match config under [code]data/match_configs/[/code].
## Like the other catalogs it is directory-backed: [method regenerate] gathers every [MatchConfig] in that
## folder. [method active] is the board's standard fallback — the config authored in [code]default.tres[/code] —
## pinned by path so the scan order can't change which one the board loads. The editor edits a config via
## [MatchConfigDetailView].

const _DIRECTORY := "res://data/match_configs"

## The authored standard config — the one [method active] returns, and the independent copy [method default_config] hands out.
const DEFAULT_PATH := "res://data/match_configs/default.tres"

@export var configs: Array[MatchConfig] = []


func entries() -> Array:
	return configs


func entry_title(entry: Resource) -> String:
	var config := entry as MatchConfig
	if config == null:
		return "Match Config"
	if config.config_name != &"":
		return String(config.config_name).capitalize()
	if not config.resource_path.is_empty():
		return config.resource_path.get_file().get_basename().capitalize()
	return "Match Config"


func matches(entry: Resource) -> bool:
	return entry is MatchConfig


func add_new() -> Resource:
	var config := default_config()
	configs.append(config)
	return config


func remove_entry(entry: Resource) -> void:
	var config := entry as MatchConfig
	if config != null:
		configs.erase(config)


## The standard config the board loads — the one authored in [code]default.tres[/code], found by path so the
## scan order doesn't matter. Falls back to the first entry, then a fresh default config, if it isn't present.
func active() -> MatchConfig:
	for config: MatchConfig in configs:
		if config != null and config.resource_path == DEFAULT_PATH:
			return config
	return configs[0] if not configs.is_empty() else default_config()


## A fresh deep copy of the standard config authored in [code]default.tres[/code], so callers (and tests) edit
## independent instances. The one place the standard config is sourced now that it's authored, not code.
static func default_config() -> MatchConfig:
	var authored := load(DEFAULT_PATH) as MatchConfig
	return authored.duplicate(true) if authored != null else MatchConfig.new()


static func default() -> MatchConfigCatalog:
	var catalog := MatchConfigCatalog.new()
	catalog.catalog_name = "Match Configs"
	catalog.directory = _DIRECTORY
	catalog.regenerate()
	return catalog
