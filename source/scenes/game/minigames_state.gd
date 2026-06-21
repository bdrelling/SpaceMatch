class_name MinigamesState
extends Resource
## The minigames' own slice of the game state — state only the minigames have, which the 3D game
## never reads. Currently empty: each minigame adds its own saved fields here as it needs them. Lives
## under [member GameState.minigames], serialized with the one save.
