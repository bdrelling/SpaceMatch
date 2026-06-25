# AUTOLOAD: DebugConfig
extends Node
## The board's view of the editable config. [member match_rules] is the active rule set from the
## [RuleCatalog] ([Catalogs.rules]) — a match with no authored rules of its own falls back to it (see
## [MatchMinigame]), and the debug/read-only rule views edit/show that same instance, so there's one source
## of truth. A thin indirection so the match needn't know about the catalog layer.

## The active rule set the board reads — the [RuleCatalog]'s first entry.
var match_rules: MatchRules:
	get:
		return Catalogs.rules.active()

## The board-level config (size, min run, warp on/off) the running match falls back to and the Debug panel
## tunes. One shared instance — a match with no authored config of its own reads this (see [MatchMinigame]).
var match_config: MatchConfig = MatchConfig.new()

## The running game's state, set by the match when its session binds (null when no encounter is live). Lets
## the live stat editor reach the encounter's health and per-combatant stat layer to tune them mid-match.
## Debug-only — gameplay never reads this.
var active_state: GameState
