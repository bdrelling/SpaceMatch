# AUTOLOAD: DebugConfig
extends Node
## The board's view of the editable config. [member match_ruleset] is the active mode from the [RuleCatalog]
## ([Catalogs.rules]) — a match with no authored ruleset of its own falls back to it (see [MatchGame]), and
## the debug/read-only rule views edit/show that same instance, so there's one source of truth. A thin
## indirection so the match needn't know about the catalog layer.

## The active mode the board reads — the [RuleCatalog]'s first entry (a [Ruleset]).
var match_ruleset: Ruleset:
	get:
		return Catalogs.rules.active()

## The board-level config (size, min run, warp on/off) the running match falls back to and the Debug panel
## tunes. One shared instance — a match with no authored config of its own reads this (see [MatchGame]).
var match_config: MatchConfig = MatchConfig.new()

## The running game's state, set by the match when its session binds (null when no encounter is live). Lets
## the live stat editor reach the encounter's health and per-combatant stat layer to tune them mid-match.
## Debug-only — gameplay never reads this.
var active_state: GameState
