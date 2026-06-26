class_name MainMenu
extends Control
## The title screen — the first thing the player sees once [main] boots into it. Today the game still
## boots straight into [Game] for a fast dev loop; this is the screen [main] is meant to land on first
## eventually. Play opens the play submenu (Campaign / Quick Match / Back); Quit exits the app. Also the
## destination of the in-game Settings overlay's Quit, which transitions back here.

#region Constants

## Loaded on demand in [method create] rather than `preload`-ed, mirroring [Game]: referencing
## [MainMenu] (e.g. from a boot-time switch) never pulls the scene into memory — only [method create] does.
const SCENE_PATH := "res://scenes/main_menu/main_menu.tscn"

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
	# Quit is a desktop affordance — a mobile app is exited by the OS, not an in-app button. Hidden on
	# mobile, shown on desktop (matching the platform split [Game.apply_window] keys off).
	_quit_button.visible = not OS.has_feature("mobile")

	_play_button.pressed.connect(_on_play_pressed)
	_debug_button.pressed.connect(_on_debug_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	# Both modes lead into the loadout screen for now; Campaign is disabled (grayed) until it's built,
	# but is wired so it routes correctly the moment it's enabled.
	_campaign_button.pressed.connect(_on_loadout_requested)
	_quick_match_button.pressed.connect(_on_loadout_requested)
	_back_button.pressed.connect(_on_back_pressed)

	_footnote.text = _build_stamp()

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
# [DebugConfig.match_rules], so they're in force the next time a match starts.
func _on_debug_pressed() -> void:
	SceneLoader.transition_to(DebugScreen.create())

func _on_quit_pressed() -> void:
	get_tree().quit()

# When this build was produced, read off the running binary's timestamp. On an exported build (e.g. the
# phone) that's the actual build time; in the editor there's no build step, so we fall back to project.godot's
# mtime as the closest "last touched" proxy. Shown local, since it's a human-facing footnote.
func _build_stamp() -> String:
	var path := OS.get_executable_path()
	if OS.has_feature("editor"):
		path = ProjectSettings.globalize_path("res://project.godot")
	var unix := FileAccess.get_modified_time(path)
	if unix == 0:
		return ""
	var bias: int = Time.get_time_zone_from_system().bias
	var t := Time.get_datetime_dict_from_unix_time(int(unix) + bias * 60)
	return "Built %04d-%02d-%02d %02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute]

static func create() -> MainMenu:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()

#endregion
