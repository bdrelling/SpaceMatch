class_name MainMenu
extends Control
## The title screen — the first thing the player sees once [main] boots into it. Today the game still
## boots straight into [Game] for a fast dev loop; this is the screen [main] is meant to land on first
## eventually. Play starts a fresh game; Quit exits the app. Also the destination of the in-game
## Settings overlay's Quit, which transitions back here.

#region Constants

## Loaded on demand in [method create] rather than `preload`-ed, mirroring [Game]: referencing
## [MainMenu] (e.g. from a boot-time switch) never pulls the scene into memory — only [method create] does.
const SCENE_PATH := "res://scenes/main_menu/main_menu.tscn"

#endregion

#region Properties

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton

#endregion

#region Lifecycle

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

#endregion

#region Methods

# Play drops straight into a fresh game. The window was already shaped for the touch UI at boot
# ([method Game.apply_window]), so the transition just swaps scenes.
func _on_play_pressed() -> void:
	SceneLoader.transition_to(Game.create())

func _on_quit_pressed() -> void:
	get_tree().quit()

static func create() -> MainMenu:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()

#endregion
