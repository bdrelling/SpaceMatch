class_name Game
extends Control
## The 2D game shell — the production entry shipped to mobile/web, NOT the debug grid playground
## switcher. The chrome (a full-bleed gradient background, the [GameTopBar], a swipeable [GamePager] of
## stage pages, and the context [GameInventoryBar]) is authored in [code]game.tscn[/code]; the top bar's
## leading button drills from the primary stage into Outfitting and steps back, so there's no tab bar.
## Each bar bleeds its background through the device safe area while holding
## its content inside it. This script wires the chrome to the pages and owns the live game state: one
## [GameSession] and a [Clock] (the game's tick
## heartbeat). A mobile app — no escape key, no 3D world.
##
## A stage is just its board plus a small view-model ([Minigame]); the shell reads the active stage's
## title, status, actions, and inventory and renders them in the chrome, so no stage draws its own bars.

#region Constants

## Loaded on demand in [method create] rather than `preload`-ed, so referencing [Game] (e.g. from
## a boot-time platform switch) never pulls the scene into memory — only [method create] does.
const SCENE_PATH := "res://scenes/game/game.tscn"

#endregion

#region Properties

## The running game's live state — a fresh single-player game, rebuilt by [method restart].
var session: GameSession

# The chrome — authored in the scene, injected here.
@export var _pager: GamePager
@export var _top_bar: GameTopBar
@export var _inventory_bar: GameInventoryBar
## The Settings overlay — a top-most [CanvasLayer] shown while the game is paused, drawn over the
## still-rendered (but frozen) game. Authored in the scene, injected here.
@export var _settings_overlay: CanvasLayer

var _clock: Clock

# Pager indices of the playable stages, in tree order — [0] is the primary stage (Encounter), the rest
# are drilled into from it. Drives the leading button's drill/back and the --tab debug hook. Settings is
# not a page but a top-most overlay (opened by pausing), so it isn't indexed here.
var _stage_indices: Array[int] = []
# The stage whose view-model is wired to the chrome right now; tracked so its signals are disconnected
# before another page binds.
var _bound_minigame: Minigame

# Portrait design resolution the responsive UI is authored against. Mobile scales the whole UI to fill
# the device screen from this base; desktop keeps the height and derives the width from the launched
# window's aspect so the portrait container matches the window exactly. Applied at boot by [method apply_window].
const _DESIGN_SIZE := Vector2i(1080, 1920)

#endregion

#region Lifecycle

func _ready() -> void:
	_index_screens()
	_wire_chrome()
	_start_game()
	_on_page_changed(_current_index())
	_apply_launch_tab()

#endregion

#region Methods

## Tears down the current game and starts a fresh one. The chrome and its pages persist — only the
## session, inventory, and clock are rebuilt, then the pages are rebound to them and the chrome
## refreshed against the active stage.
func restart() -> void:
	_teardown_game()
	_start_game()
	_on_page_changed(_current_index())

# Collects the pager indices of the playable stages in tree order, so the leading button and the --tab
# hook map a stage to its pager index. Settings is an overlay, not a page, so it isn't indexed here.
func _index_screens() -> void:
	_stage_indices.clear()
	for index: int in _pager.screens.size():
		if _pager.screens[index] is MinigameScreen:
			_stage_indices.append(index)

# Connects the chrome: the cog opens Settings, the leading button drills/steps back between stages,
# the Settings panel's Restart/Quit are handled by the shell (they touch the session and scene).
func _wire_chrome() -> void:
	_top_bar.settings_pressed.connect(_on_settings_pressed)
	_top_bar.leading_pressed.connect(_on_leading_pressed)
	PauseMonitor.paused.connect(_open_settings)
	PauseMonitor.unpaused.connect(_close_settings)
	_settings_dim().gui_input.connect(_on_settings_dim_input)
	_settings_screen().restart_pressed.connect(_on_settings_restart)
	_settings_screen().quit_pressed.connect(_on_settings_quit)
	_pager.page_changed.connect(_on_page_changed)

# Debug capture hook: `--tab=N` lands the game on the Nth playable stage at boot so a single
# playtest screenshot can target one minigame. Inert without the argument — normal runs start on stage 0.
func _apply_launch_tab() -> void:
	if not CommandLine.has_launch_argument_key("tab"):
		return
	_show_stage(int(CommandLine.get_launch_argument_value("tab", "0")))

# Pages to the [param stage]th playable stage (0 = the primary Encounter stage).
func _show_stage(stage: int) -> void:
	if stage < 0 or stage >= _stage_indices.size():
		return
	_pager.show_index(_stage_indices[stage])

# The pager index of the primary stage (Encounter) — where the leading button shows the grid glyph and
# "back" returns to.
func _primary_screen_index() -> int:
	return _stage_indices[0] if not _stage_indices.is_empty() else 0

# The leading button drills from the primary stage into Outfitting (grid glyph) and steps back from a
# sub-screen (back arrow). Two stages today, so the drill target is the last stage and "back" is stage 0.
func _on_leading_pressed() -> void:
	if _current_index() == _primary_screen_index():
		_show_stage(_stage_indices.size() - 1)
	else:
		_show_stage(0)

# The cog opens Settings the same way the pause action does — by pausing the game, which the overlay
# shows itself over. On mobile there's no ESC/joypad, so the cog is the way in.
func _on_settings_pressed() -> void:
	PauseMonitor.pause()

# Settings is a top-most overlay shown while paused — the screen's Done button resumes, and tapping the
# dim outside the panel does too (touch has no ESC/joypad). Resuming hides it.
func _open_settings() -> void:
	_settings_overlay.visible = true

func _close_settings() -> void:
	_settings_overlay.visible = false

func _settings_dim() -> Control:
	return _settings_overlay.get_node("Dim")

func _settings_screen() -> SettingsScreen:
	return _settings_overlay.get_node("Settings") as SettingsScreen

func _on_settings_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		PauseMonitor.unpause()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		PauseMonitor.unpause()

# Restart from the Settings panel: resume first (the new game must run unpaused), then rebuild the
# session in place — the chrome and pages persist.
func _on_settings_restart() -> void:
	PauseMonitor.unpause()
	restart()

# Quit from the Settings panel: resume so the tree isn't left paused under the menu, then transition
# out of the game shell back to the main menu.
func _on_settings_quit() -> void:
	PauseMonitor.unpause()
	SceneLoader.transition_to(MainMenu.create())

# Shows the back arrow on a sub-screen and hides the leading button on the primary stage (which drills
# from its own HUD), then points the chrome's actions and inventory strip at the page now visible.
func _on_page_changed(index: int) -> void:
	if index == _primary_screen_index():
		_top_bar.hide_leading()
	else:
		_top_bar.show_leading(GameTopBar.LEADING_BACK)
	var screen: GameScreen = null
	if index >= 0 and index < _pager.screens.size():
		screen = _pager.screens[index]
	_bind_chrome(screen)

func _bind_chrome(screen: GameScreen) -> void:
	_unbind_minigame()
	if screen == null:
		return
	var game: Minigame = null
	if screen is MinigameScreen:
		game = (screen as MinigameScreen).minigame()
	if game == null:
		var no_actions: Array[MinigameAction] = []
		_top_bar.set_actions(no_actions)
		_inventory_bar.bind(null)
		return
	_bound_minigame = game
	_top_bar.set_actions(game.actions())
	_inventory_bar.bind(game)
	game.inventory_changed.connect(_inventory_bar.refresh)
	game.actions_changed.connect(_refresh_actions)
	game.drill_requested.connect(_on_drill_requested)

func _refresh_actions() -> void:
	if _bound_minigame != null:
		_top_bar.set_actions(_bound_minigame.actions())

# A stage asked to drill into a combatant's loadout — point Outfitting at that ship, then open it (the
# last stage). With no ship, Outfitting keeps whatever grid it was last bound to (the player's, by default).
func _on_drill_requested(starship: StarshipState) -> void:
	var outfitting: OutfittingMinigame = _outfitting_stage()
	if outfitting != null and starship != null:
		outfitting.show_starship(starship)
	_show_stage(_stage_indices.size() - 1)

# The OutfittingMinigame behind the last playable stage, or null if it isn't one (defensive — the
# drill target is always Outfitting today).
func _outfitting_stage() -> OutfittingMinigame:
	if _stage_indices.is_empty():
		return null
	var index: int = _stage_indices[_stage_indices.size() - 1]
	if index < 0 or index >= _pager.screens.size():
		return null
	var screen: GameScreen = _pager.screens[index]
	if screen is MinigameScreen:
		return (screen as MinigameScreen).minigame() as OutfittingMinigame
	return null

func _unbind_minigame() -> void:
	if _bound_minigame == null:
		return
	if _bound_minigame.inventory_changed.is_connected(_inventory_bar.refresh):
		_bound_minigame.inventory_changed.disconnect(_inventory_bar.refresh)
	if _bound_minigame.actions_changed.is_connected(_refresh_actions):
		_bound_minigame.actions_changed.disconnect(_refresh_actions)
	if _bound_minigame.drill_requested.is_connected(_on_drill_requested):
		_bound_minigame.drill_requested.disconnect(_on_drill_requested)
	_bound_minigame = null

func _current_index() -> int:
	for index: int in _pager.screens.size():
		if _pager.screens[index].visible:
			return index
	return 0

func _start_game() -> void:
	session = GameSession.new_game()
	# The active encounter's slice of the save — state the 3D game never reads.
	session.state.encounter = EncounterState.new()

	# The game's tick heartbeat. Nothing drives scrap yet — resource production (a tap now, an
	# upgraded interval later) subscribes to `_clock.ticked` when it lands.
	_clock = Clock.new()
	add_child(_clock)

	for screen: GameScreen in _pager.screens:
		screen.bind(session)

func _teardown_game() -> void:
	if _clock != null:
		_clock.queue_free()
	_clock = null

static func create() -> Game:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()

## Sets [param window]'s content scaling for the game's touch UI (canvas-items in both cases). The
## window's size and shape come entirely from the launch — the platform on a real device, the `make
## game` targets' `--resolution` on desktop — and nothing is resized here.
##
## Mobile fills the device screen edge-to-edge (EXPAND): the platform owns the real portrait
## resolution, which isn't yet reflected in [member Window.size] at boot, so the UI simply reflows to
## fill whatever it gets rather than locking to a measured aspect. Desktop locks to the launched
## window's aspect (KEEP) — here [member Window.size] is reliable (the window opened synchronously at
## the requested resolution) — so it fills with no letterbox at launch, then letterboxes on resize
## rather than squashing the view square or landscape.
static func apply_window(window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if OS.has_feature("mobile"):
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		window.content_scale_size = _DESIGN_SIZE
	else:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		var aspect: float = float(window.size.x) / float(window.size.y)
		window.content_scale_size = Vector2i(roundi(_DESIGN_SIZE.y * aspect), _DESIGN_SIZE.y)

## The safe area the chrome insets its content against. On a handheld this is the device's real safe
## area. Desktop and web report none, so a launch that emulates a handheld — a portrait window, as the
## `make play`/`play-phone` targets open — substitutes a mocked mobile safe area; an ordinary landscape
## desktop window is left as-is with no insets.
static func safe_area(viewport: Viewport) -> SafeArea:
	if not OS.has_feature("mobile"):
		var size := viewport.get_visible_rect().size
		if size.y > size.x:
			return SafeArea.mocked_mobile()
	return DeviceUtils.get_safe_area(viewport)

#endregion
