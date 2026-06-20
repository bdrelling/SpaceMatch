# AUTOLOAD: Settings
extends Node
## Root access point for persisted settings, grouped by type.
##
## Each group is a typed accessor that resolves reads to the player's overrides
## or the shipped defaults, and persists overrides to disk. Consumers go through
## these groups (e.g. [code]Settings.game.camera_mode[/code]) rather than
## reading or writing settings files directly. Add future groups (minigames,
## audio, ...) as sibling members here.

var game: GameSettings

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = GameSettings.new()
