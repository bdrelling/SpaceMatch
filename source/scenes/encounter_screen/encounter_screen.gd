class_name EncounterScreen
extends ScreenFrame
## The encounter — the match presented as its own screen: a [ScreenFrame] hosting the raw match feature
## scene ([code]match.tscn[/code]) in its content slot. Reached from [LoadoutScreen]'s Launch, so it reads
## the running game (the [code]GameSession[/code] autoload) the player just set up; Back returns to the
## [MainMenuScreen]. The bar's settings cog opens a top-most [SettingsScreen] overlay over the paused match.

const SCENE_PATH := "res://scenes/encounter_screen/encounter_screen.tscn"

@onready var _match: MatchMinigame = %Match
@onready var _footnote: Label = %Footnote
## The Settings overlay — a top-most [CanvasLayer] shown while the match is paused, drawn over the
## still-rendered (but frozen) board. Authored in the scene.
@onready var _settings_overlay: CanvasLayer = %SettingsOverlay

# The encounter this screen hosts (a clone of the running starship vs the computer default). Owned here so the
# match screen only renders it; pointed into GameSession.game_state.encounter.
var _encounter: Encounter

func _ready() -> void:
	super._ready()  # wire the frame's bar signals
	_open_encounter()
	_match.bind_session()
	# This screen owns the encounter, so the match's Restart reopens it here.
	_match.restart_requested.connect(_open_encounter)
	configure_bar("Encounter")
	# The cog is the only way to pause on touch (no ESC/joypad), so the encounter shows it.
	show_settings(true)
	settings_pressed.connect(_on_settings_pressed)
	back_pressed.connect(_on_back)
	_wire_settings()

	# Build watermark — debug builds only; released encounters stay clean.
	_footnote.visible = OS.is_debug_build()
	if _footnote.visible:
		_footnote.text = BuildInfo.stamp()

# Connects the Settings overlay: pausing shows it, resuming hides it, and its panel buttons restart/quit
# the encounter or open Debug over the (still paused) board.
func _wire_settings() -> void:
	PauseMonitor.paused.connect(_open_settings)
	PauseMonitor.unpaused.connect(_close_settings)
	var settings := _settings_screen()
	settings.restart_pressed.connect(_on_settings_restart)
	settings.quit_pressed.connect(_on_settings_quit)
	settings.debug_pressed.connect(_on_settings_debug)

# Opens (or reopens) the encounter this screen hosts: a fresh [Encounter] with a clone of the running
# starship, pointed into the session so the match reads it. Frees any prior encounter so a restart doesn't
# leak it.
func _open_encounter() -> void:
	if _encounter != null:
		_encounter.queue_free()
	var player_clone: StarshipState = GameSession.game_state.starship.clone() if GameSession.game_state.starship != null else null
	_encounter = Encounter.create(player_clone)
	_encounter.name = "Encounter"
	add_child(_encounter)
	GameSession.game_state.encounter = _encounter.state

# The cog pauses (touch has no ESC/joypad); the overlay shows itself over the frozen board on pause.
func _on_settings_pressed() -> void:
	PauseMonitor.pause()

func _open_settings() -> void:
	_settings_overlay.visible = true

func _close_settings() -> void:
	_settings_overlay.visible = false

func _settings_screen() -> SettingsScreen:
	return _settings_overlay.get_node("Settings") as SettingsScreen

# Restart from Settings: resume first (the new match must run unpaused), then reopen the encounter in place.
func _on_settings_restart() -> void:
	PauseMonitor.unpause()
	_open_encounter()

# Quit from Settings: resume so the tree isn't left paused under the menu, then return to the main menu.
func _on_settings_quit() -> void:
	PauseMonitor.unpause()
	SceneLoader.transition_to(MainMenuScreen.create())

# Debug from Settings: open the debug navigator over the (still paused) board, above the Settings overlay.
# Its pages edit the same shared config the running board uses, so changes apply live; Done frees it.
func _on_settings_debug() -> void:
	var navigator := DebugNavigator.create(DebugHomeView.new())
	navigator.closed.connect(navigator.queue_free)
	_settings_overlay.add_child(navigator)

func _on_back() -> void:
	SceneLoader.transition_to(MainMenuScreen.create())

static func create() -> EncounterScreen:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()
