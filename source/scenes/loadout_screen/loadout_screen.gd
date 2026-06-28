class_name LoadoutScreen
extends ScreenFrame
## The pre-match loadout screen — Quick Match's first stop. A [ScreenFrame] hosting the raw loadout
## feature scene in its content slot: Back returns to the [MainMenu], Launch enters the match carrying the
## loadout just set. The player edits the running game's starship (the [code]GameSession[/code] autoload) here;
## the encounter reads that same session, so the match plays with exactly this loadout.

const SCENE_PATH := "res://scenes/loadout_screen/loadout_screen.tscn"

@onready var _loadout: LoadoutMinigame = %Loadout

func _ready() -> void:
	super._ready()  # wire the frame's bar signals
	# Start a fresh game so the loadout edits this run's starship; the encounter launched below reads the same
	# session, so it plays with exactly this loadout.
	GameSession.start_new_game()
	_loadout.bind_session()
	_loadout.set_mode(LoadoutMinigame.Mode.SELECT)
	configure_bar("Loadout", "Launch")
	back_pressed.connect(_on_back)
	action_pressed.connect(_on_launch)

func _on_back() -> void:
	SceneLoader.transition_to(MainMenu.create())

# Launch: enter the full game shell with the loadout just set. The shell reuses the running session (it only
# resets on restart), so the match's player starship is exactly this loadout — and it carries the encounter bars
# (settings cog, Rules), matching the boot-into-game experience.
func _on_launch() -> void:
	SceneLoader.transition_to(Game.create())

static func create() -> LoadoutScreen:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()
