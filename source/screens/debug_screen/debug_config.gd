# AUTOLOAD: DebugConfig
extends Node
## The board's view of the editable config. [member match_config] is the active [MatchConfig] from the
## [MatchConfigCatalog] ([Catalogs.match_configs]) unless a debug "Play this mode" (or a test) overrode it, and
## [member match_ruleset] is that config's referenced mode. A match with no config/ruleset of its own falls back
## to these (see [MatchGame]), and the debug/read-only views edit/show the same instances, so there's one source
## of truth. A thin indirection so the match needn't know about the catalog layer.

## The running game's state, set by the match when its session binds (null when no encounter is live). Lets
## the live stat editor reach the encounter's health and per-combatant stat layer to tune them mid-match.
## Debug-only — gameplay never reads this.
var active_state: GameState

## The active mode the board reads — the [Ruleset] referenced by [member match_config], or the [RuleCatalog]'s
## active ruleset when the config names none.
var match_ruleset: Ruleset:
	get:
		var config := match_config
		if config != null and config.ruleset != null:
			return config.ruleset
		return Catalogs.rules.active()

## The board-level config the running match reads (size, shortest run, team size, and the ruleset it references).
## Defaults to the [MatchConfigCatalog]'s active config; assigning it overrides which config the next board
## builds with (the debug "Play this mode" button, or a test).
var match_config: MatchConfig:
	get:
		return _match_config if _match_config != null else Catalogs.match_configs.active()
	set(value):
		_match_config = value

# The config the next board builds with, when set — a debug selection ("Play this mode") or a test override.
# Null means "use the catalog's active config".
var _match_config: MatchConfig
