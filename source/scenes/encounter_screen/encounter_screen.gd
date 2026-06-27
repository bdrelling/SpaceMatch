class_name EncounterScreen
extends ScreenFrame
## The encounter — the match presented as its own screen: a [ScreenFrame] hosting the raw match feature
## scene ([code]match.tscn[/code]) in its content slot. The same match content the [Game] shell mounts, here
## in the lightweight standard frame instead. Reached from [LoadoutScreen]'s Launch, so it reads the running
## game (the [code]GameSession[/code] autoload) the player just set up; Back returns to the [MainMenu].

const SCENE_PATH := "res://scenes/encounter_screen/encounter_screen.tscn"

@onready var _match: MatchMinigame = %Match
@onready var _footnote: Label = %Footnote

# The encounter this screen hosts (a clone of the running ship vs the computer default). Owned here so the
# match screen only renders it; pointed into GameSession.game_state.encounter.
var _encounter: Encounter

func _ready() -> void:
	super._ready()  # wire the frame's bar signals
	_open_encounter()
	_match.bind_session()
	# This screen owns the encounter, so the match's Restart reopens it here.
	_match.restart_requested.connect(_open_encounter)
	configure_bar("Encounter")
	back_pressed.connect(_on_back)

	# Build watermark — debug builds only; released encounters stay clean.
	_footnote.visible = OS.is_debug_build()
	if _footnote.visible:
		_footnote.text = BuildInfo.stamp()

# Opens the encounter this screen hosts: a fresh [Encounter] with a clone of the running ship, pointed into
# the session so the match reads it.
func _open_encounter() -> void:
	var player_clone: StarshipState = GameSession.game_state.starship.clone() if GameSession.game_state.starship != null else null
	_encounter = Encounter.create(player_clone)
	_encounter.name = "Encounter"
	add_child(_encounter)
	GameSession.game_state.encounter = _encounter.state

func _on_back() -> void:
	SceneLoader.transition_to(MainMenu.create())

static func create() -> EncounterScreen:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()
