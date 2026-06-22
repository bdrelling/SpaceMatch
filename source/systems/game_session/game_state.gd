class_name GameState
extends Resource
## One running game's runtime state: the player's [StarshipState] and the active [EncounterState]. This is
## what a save serializes; a [GameSession] holds it live. Never a project `.tres`.

## The default starship a fresh game starts with.
const _DEFAULT_STARSHIP := preload("res://resources/starships/default_starship_blueprint.tres")

@export var starship: StarshipState

## The player's currency. Campaign-scoped (one player today); moves onto a per-player object if co-op
## ever lands.
@export var wallet: Wallet

## The active encounter's state, or null when no encounter is running. Serialized with the one save.
@export var encounter: EncounterState

func _init() -> void:
	if starship == null:
		starship = StarshipGenerator.generate(_DEFAULT_STARSHIP)
	if wallet == null:
		wallet = Wallet.new()
