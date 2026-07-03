class_name CurrencyAmount
extends Amount
## An effect magnitude read from a wallet balance — e.g. "deal damage equal to your scrap". Game-side: the engine
## only knows [Amount], so this downcasts the resolution context to the game's [MatchResolutionContext] to reach
## the [WalletState], keeping currency out of the effect engine. Mirrors [CurrentStatAmount], but reads a wallet
## balance instead of the source entity's stats — the pattern for reaching any game state a resolver needs.

## The currency whose balance this resolves to.
@export var currency: CurrencyResource


## The wallet's balance of [member currency] in [param context], or zero when the context carries no wallet (a
## non-match context) or no currency is set.
func evaluate(context: ResolutionContext) -> int:
	var match_context := context as MatchResolutionContext
	if match_context == null or match_context.wallet == null or currency == null:
		return 0
	return match_context.wallet.amount_of(currency)
