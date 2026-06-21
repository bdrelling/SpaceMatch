class_name EncounterState
extends Resource
## The active encounter's slice of the game state — state only the encounter (the match-3 play
## screen) has, which the 3D game never reads. Null on [GameState] when no encounter is running.
## Lives under [member GameState.encounter], serialized with the one save.
