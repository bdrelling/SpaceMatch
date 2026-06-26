class_name GameState
extends Resource
## One running game's runtime state: the player's [StarshipState], their [WalletState], and the active
## [EncounterState]. Pure data — this is what a save serializes; a [GameSession] holds it live and the [Game]
## node builds the entity nodes (player ship, wallet, encounter) that populate it. Never a project `.tres`.

@export var starship: StarshipState

## The player's currency. Campaign-scoped (one player today); moves onto a per-player object if co-op
## ever lands.
@export var wallet: WalletState

## The active encounter's state, or null when no encounter is running. Serialized with the one save.
@export var encounter: EncounterState
