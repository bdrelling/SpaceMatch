class_name MatchConfig
extends Resource
## Board-level settings for one match — the geometry that shapes the board itself, separate from the
## behavioural [Ruleset] (what tiles do) and the per-starship stats. Author a `.tres` and hand it to
## [MatchGame] as [member MatchGame.config], or leave it unset and the board falls back to the shared
## [member DebugConfig.match_config] so the Debug panel tunes it without a recompile. Geometry changes
## (width / height / min run) apply when the board next builds — i.e. on the next match or a restart — since
## the running board is laid out once. (Warp on/off lives on the [WarpRule]; whether a starship can warp at all is
## a warp-core module, summed into [member StarshipStats.warp_capacity].)

## The board's dimensions, in cells.
@export var board_width: int = 8
@export var board_height: int = 8

## The shortest run of one kind that pops — the match-3 "3". Feeds the line clear, swap/teleport match
## checks, and the connect-path minimum.
@export var min_run: int = 3
