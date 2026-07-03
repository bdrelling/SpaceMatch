class_name MatchResolutionContext
extends ResolutionContext
## The [ResolutionContext] the match hands its ability [Action]s: the base resolution state plus the game-side
## reach a match action or amount needs that the engine's generic context doesn't carry — the live
## [EncounterState] to drive combat through (shield, damage, disable), the player's [WalletState] (so a game-side
## [CurrencyAmount] can read a balance without the engine knowing what a wallet is), and a [member visuals] list
## the host drains to play popups and glyphs. Mirrors how [MatchRuleContext] extends [RuleContext].

## The encounter the ability resolves in — the actions read it to mutate combat state (health, shield, statuses,
## disabled cells) through the same [EncounterState] methods the rest of the match uses.
var encounter: EncounterState
## The player's wallet — game-side state a [CurrencyAmount] reads through this context, keeping currency out of the
## engine. Null outside a running game (e.g. the standalone scene).
var wallet: WalletState
## Presentation events the actions emit as they resolve — one entry per effect ([code]{"kind": ..., "target":
## ..., ...}[/code]), drained by [MatchGame] after the ability runs to play the portrait popups, health refresh
## and attack glyphs. Keeping visuals as data (not calls) keeps the actions host-agnostic.
var visuals: Array[Dictionary] = []


## Appends one presentation [param event] for the host to play once the ability finishes resolving.
func add_visual(event: Dictionary) -> void:
	visuals.append(event)
