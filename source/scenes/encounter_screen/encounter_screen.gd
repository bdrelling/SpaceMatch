class_name EncounterScreen
extends ScreenFrame
## The encounter — the match presented as its own screen: a [ScreenFrame] hosting the raw match feature
## scene ([code]match.tscn[/code]) in its content slot, with a session bound in. The same match content the
## [Game] shell mounts, here in the lightweight standard frame instead. Reached from [LoadoutScreen]'s
## Launch (carrying the loadout the player set); Back returns to the [MainMenu].

const SCENE_PATH := "res://scenes/encounter_screen/encounter_screen.tscn"

@onready var _match: MatchMinigame = %Match

# The game to play — handed in from the pre-match loadout via [method use_session] so the encounter uses
# exactly that loadout; a fresh default game when launched on its own.
var _pending_session: GameSession

func _ready() -> void:
	super._ready()  # wire the frame's bar signals
	var session: GameSession = _pending_session if _pending_session != null else GameSession.new_game()
	_match.bind_session(session)
	configure_bar("Encounter")
	back_pressed.connect(_on_back)

## Hands the encounter the session to play — set right after [method create], before it enters the tree.
func use_session(session: GameSession) -> void:
	_pending_session = session

func _on_back() -> void:
	SceneLoader.transition_to(MainMenu.create())

static func create() -> EncounterScreen:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()
