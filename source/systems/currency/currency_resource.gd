class_name CurrencyResource
extends EntityResource
## A persistent currency an entity holds — a wallet balance (scrap, gold, ...). Banked in a [ResourcePool] like any
## [EntityResource], but it lives on the game's wallet rather than a combatant's ability ("mana") pools, and it
## survives an encounter. Its own subtype so a wallet's currency reads distinctly from an [AbilityResource]. The
## effect engine only ever sees the [EntityResource] base; a game-side amount reads a currency balance off the
## wallet through the resolution context.
