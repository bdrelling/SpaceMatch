class_name Arcade
extends Control
## The 2D game shell — the production entry shipped to mobile/web, NOT the debug grid playground
## switcher. The chrome (a full-bleed background, the [ArcadeTopBar], a swipeable [ArcadePager] of stage
## pages, the context [ArcadeInventoryBar], and the bottom [ArcadeTabBar]) is authored in
## [code]arcade.tscn[/code]; each bar bleeds its background through the device safe area while holding
## its content inside it. This script wires the chrome to the pages and owns the live game state: one
## [GameSession] with a shared [Inventory] bound to its [PlayerState] and a [Clock] (the game's tick
## heartbeat). A mobile app — no escape key, no 3D world.
##
## A stage is just its board plus a small view-model ([Minigame]); the shell reads the active stage's
## title, status, actions, and inventory and renders them in the chrome, so no stage draws its own bars.

#region Constants

## Loaded on demand in [method create] rather than `preload`-ed, so referencing [Arcade] (e.g. from
## a boot-time platform switch) never pulls the scene into memory — only [method create] does.
const SCENE_PATH := "res://scenes/game/game.tscn"

#endregion

#region Properties

## The running game's live state — a fresh single-player game, rebuilt by [method restart].
var session: GameSession

# The chrome — authored in the scene, injected here.
@export var _pager: ArcadePager
@export var _tab_bar: ArcadeTabBar
@export var _top_bar: ArcadeTopBar
@export var _inventory_bar: ArcadeInventoryBar

var _inventory: Inventory
var _clock: Clock

# Pager indices of the playable stages — tab i pages to _tab_screen_indices[i]. The menu/settings page
# is reached by the top-bar cog, not a tab, so it's tracked apart.
var _tab_screen_indices: Array[int] = []
var _settings_index: int = -1
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

# Splits the pages into the tabbed stages and the cog-reached settings page, so the tab bar carries only
# the playable stages and a swipe/tab maps to the right pager index.
func _index_screens() -> void:
	_tab_screen_indices.clear()
	_settings_index = -1
	for index: int in _pager.screens.size():
		var screen: ArcadeScreen = _pager.screens[index]
		if screen is MinigameScreen:
			_tab_screen_indices.append(index)
		elif _settings_index < 0:
			_settings_index = index

# Connects the chrome and labels the tabs from the stages' own titles — each page owns its name, the
# tab just mirrors it.
func _wire_chrome() -> void:
	_tab_bar.tab_selected.connect(_on_tab_selected)
	_top_bar.settings_pressed.connect(_on_settings_pressed)
	_pager.page_changed.connect(_on_page_changed)
	var titles: Array[String] = []
	for index: int in _tab_screen_indices:
		titles.append(_pager.screens[index].title)
	_tab_bar.set_labels(titles)

# Debug capture hook: `--tab=N` lands the arcade on the Nth playable stage at boot so a single
# playtest screenshot can target one minigame. Inert without the argument — normal runs start on tab 0.
func _apply_launch_tab() -> void:
	if not CommandLine.has_launch_argument_key("tab"):
		return
	_on_tab_selected(int(CommandLine.get_launch_argument_value("tab", "0")))

func _on_tab_selected(tab_index: int) -> void:
	if tab_index < 0 or tab_index >= _tab_screen_indices.size():
		return
	_pager.show_index(_tab_screen_indices[tab_index])

func _on_settings_pressed() -> void:
	if _settings_index >= 0:
		_pager.show_index(_settings_index)

# Keeps the tab highlight in sync (cleared on the settings page) and points the chrome's title, status,
# actions, and inventory strip at the page that just became visible.
func _on_page_changed(index: int) -> void:
	_tab_bar.set_active(_tab_screen_indices.find(index))
	var screen: ArcadeScreen = null
	if index >= 0 and index < _pager.screens.size():
		screen = _pager.screens[index]
	_bind_chrome(screen)

func _bind_chrome(screen: ArcadeScreen) -> void:
	_unbind_minigame()
	if screen == null:
		return
	_top_bar.set_title(screen.title)
	var game: Minigame = null
	if screen is MinigameScreen:
		game = (screen as MinigameScreen).minigame()
	if game == null:
		var no_actions: Array[MinigameAction] = []
		_top_bar.set_status("")
		_top_bar.set_actions(no_actions)
		_inventory_bar.bind(null)
		return
	_bound_minigame = game
	_top_bar.set_status(game.status_text)
	_top_bar.set_actions(game.actions())
	_inventory_bar.bind(game)
	game.status_changed.connect(_top_bar.set_status)
	game.inventory_changed.connect(_inventory_bar.refresh)
	game.actions_changed.connect(_refresh_actions)

func _refresh_actions() -> void:
	if _bound_minigame != null:
		_top_bar.set_actions(_bound_minigame.actions())

func _unbind_minigame() -> void:
	if _bound_minigame == null:
		return
	if _bound_minigame.status_changed.is_connected(_top_bar.set_status):
		_bound_minigame.status_changed.disconnect(_top_bar.set_status)
	if _bound_minigame.inventory_changed.is_connected(_inventory_bar.refresh):
		_bound_minigame.inventory_changed.disconnect(_inventory_bar.refresh)
	if _bound_minigame.actions_changed.is_connected(_refresh_actions):
		_bound_minigame.actions_changed.disconnect(_refresh_actions)
	_bound_minigame = null

func _current_index() -> int:
	for index: int in _pager.screens.size():
		if _pager.screens[index].visible:
			return index
	return 0

func _start_game() -> void:
	session = GameSession.new_game()
	# The arcade owns its own slice of the save — arcade-only state the 3D game never reads.
	session.state.arcade = ArcadeState.new()
	_inventory = Inventory.new()
	add_child(_inventory)
	session.bind_inventory(_inventory)

	# The game's tick heartbeat. Nothing drives scrap yet — resource production (a tap now, an
	# upgraded interval later) subscribes to `_clock.ticked` when it lands.
	_clock = Clock.new()
	add_child(_clock)

	for screen: ArcadeScreen in _pager.screens:
		screen.bind(session, _inventory)

func _teardown_game() -> void:
	for node: Node in [_clock, _inventory]:
		if node != null:
			node.queue_free()
	_clock = null
	_inventory = null

static func create() -> Arcade:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()

## Sets [param window]'s content scaling for the arcade's touch UI (canvas-items in both cases). The
## window's size and shape come entirely from the launch — the platform on a real device, the `make
## arcade` targets' `--resolution` on desktop — and nothing is resized here.
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

#endregion
