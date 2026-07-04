class_name MatchConfig
extends Resource
## Configures one match: the player-tunable settings that shape a match — board geometry, shortest run, team
## size — plus a reference to the [Ruleset] (the game mode) it plays under. It *uses* a ruleset; it never
## embeds or owns one, so an 8×8 and a 10×10 config can point at the same ruleset without touching the rules.
## Author a `.tres` in [code]data/match_configs/[/code] (gathered by [MatchConfigCatalog]) and hand it to
## [MatchGame] as [member MatchGame.config], or leave that unset and the board falls back to the active config on
## [member DebugConfig.match_config] so the Debug panel tunes it without a recompile. Geometry changes (width /
## height / min run) apply when the board next builds — i.e. on the next match or a restart — since the running
## board is laid out once. (Warp on/off lives on the [WarpRule]; whether a starship can warp at all is a
## warp-core module, summed into [member StarshipStats.warp_capacity].)

## A short display name for the config, so a mode reads as one player-facing line in the picker.
@export var config_name: StringName = &""

## The game mode this match plays — a reference to an authored [Ruleset] in the [RuleCatalog]. A reference, never
## an embedded copy, so many configs can share one ruleset. Left null, the board falls back to
## [member DebugConfig.match_ruleset].
@export var ruleset: Ruleset

## The board's dimensions, in cells.
@export var board_width: int = 8
@export var board_height: int = 8

## The shortest run of one kind that pops — the match-3 "3". Feeds the line clear, swap/teleport match
## checks, and the connect-path minimum.
@export var min_run: int = 3

## How many starships a side fields. Reserved and forward-compatible — play is 1v1 today (see the encounter
## model), so this stays 1 until multi-starship combat lands.
@export var team_size: int = 1
