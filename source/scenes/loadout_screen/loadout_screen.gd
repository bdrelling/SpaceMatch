class_name LoadoutScreen
extends ScreenFrame
## The pre-match loadout screen — Quick Match's first stop. A [ScreenFrame] hosting the raw loadout
## feature scene in its content slot: Back returns to the [MainMenu], Launch enters the match carrying the
## loadout just set. Self-contained — it owns the [GameSession] the player edits here and hands it to
## [Game] on launch, so the match plays with exactly this loadout.

const SCENE_PATH := "res://scenes/loadout_screen/loadout_screen.tscn"

@onready var _loadout: LoadoutMinigame = %Loadout

# The game being set up. The player edits this ship's module grid here; on Launch the whole session is
# handed to [Game], so the match plays with exactly this loadout rather than a fresh default one.
var _session: GameSession

func _ready() -> void:
	super._ready()  # wire the frame's bar signals
	_session = GameSession.new_game()
	_loadout.bind_session(_session)
	_loadout.set_mode(LoadoutMinigame.Mode.SELECT)
	configure_bar("Loadout", "Launch")
	back_pressed.connect(_on_back)
	action_pressed.connect(_on_launch)

func _on_back() -> void:
	SceneLoader.transition_to(MainMenu.create())

# Launch: enter the encounter with the loadout just set. The session the player edited is handed to the
# [EncounterScreen], so the match's player ship is exactly this loadout.
func _on_launch() -> void:
	var encounter := EncounterScreen.create()
	encounter.use_session(_session)
	SceneLoader.transition_to(encounter)

static func create() -> LoadoutScreen:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()
