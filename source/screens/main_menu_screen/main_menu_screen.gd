class_name MainMenuScreen
extends Control
## The title screen — the first thing the player sees once [main] boots into it. Play opens the play submenu
## (Campaign / Quick Match / Back), which leads into the [LoadoutScreen]; Quit exits the app. Also the
## destination of the encounter Settings overlay's Quit, which transitions back here.

#region Constants

## Loaded on demand in [method create] rather than `preload`-ed, mirroring the other screens: referencing
## [MainMenuScreen] (e.g. from a boot-time switch) never pulls the scene into memory — only [method create] does.
const SCENE_PATH := "res://screens/main_menu_screen/main_menu_screen.tscn"

#endregion

#region Properties

# The two button groups occupy the same spot in the layout; Play/Back toggle which one is shown.
@onready var _main_buttons: VBoxContainer = %MainButtons
@onready var _play_menu: VBoxContainer = %PlayMenu

@onready var _play_button: Button = %PlayButton
@onready var _debug_button: Button = %DebugButton
@onready var _quit_button: Button = %QuitButton

@onready var _campaign_button: Button = %CampaignButton
@onready var _quick_match_button: Button = %QuickMatchButton
@onready var _back_button: Button = %BackButton

@onready var _footnote: Label = %Footnote

#endregion

#region Lifecycle

func _ready() -> void:
	# Quit is a desktop affordance — a handheld app is exited by the OS, not an in-app button. Hidden on
	# phone/tablet (real or a `make play-phone`/`play-tablet` preview), shown on desktop.
	_quit_button.visible = not DeviceInfo.is_handheld()

	_play_button.pressed.connect(_on_play_pressed)
	_debug_button.pressed.connect(_on_debug_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	# Both modes lead into the loadout screen for now; Campaign is disabled (grayed) until it's built,
	# but is wired so it routes correctly the moment it's enabled.
	_campaign_button.pressed.connect(_on_loadout_requested)
	_quick_match_button.pressed.connect(_on_loadout_requested)
	_back_button.pressed.connect(_on_back_pressed)

	_footnote.text = BuildInfo.stamp()

#endregion

#region Methods

# Play swaps the root buttons for the play submenu rather than starting a game directly.
func _on_play_pressed() -> void:
	_main_buttons.visible = false
	_play_menu.visible = true

# Back returns from the play submenu to the root buttons.
func _on_back_pressed() -> void:
	_play_menu.visible = false
	_main_buttons.visible = true

# Campaign / Quick Match both open the [LoadoutScreen] first — the player sets their starship loadout
# there, then Launch enters the match carrying it. The screen is self-contained (its own background and
# safe area via [ScreenContainer]), so the transition just swaps scenes.
func _on_loadout_requested() -> void:
	SceneLoader.transition_to(LoadoutScreen.create())

# Debug opens the on-device tuning screen (match-rules sliders today). The edits land on the shared
# [DebugConfig.match_ruleset], so they're in force the next time a match starts.
func _on_debug_pressed() -> void:
	SceneLoader.transition_to(DebugScreen.create())

func _on_quit_pressed() -> void:
	get_tree().quit()

static func create() -> MainMenuScreen:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()

#endregion
