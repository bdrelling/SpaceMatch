extends GdUnitTestSuite
## The loadout screen's mode-gated editing and the focused-module stat readout: modules can be dragged
## only in the editable modes (EDIT / SELECT); READ_ONLY (mid-combat) is inspect-only. Tapping a module
## focuses it in any mode.

# A bare minigame, no scene tree — enough to exercise mode and [method _editable], which don't touch the
# view nodes.
func _minigame() -> LoadoutMinigame:
	return auto_free(LoadoutMinigame.new())

# The full scene mounted in the tree, so the @onready view + label nodes resolve.
func _scene() -> LoadoutMinigame:
	var scene: LoadoutMinigame = auto_free((load("res://minigames/loadout/loadout.tscn") as PackedScene).instantiate())
	add_child(scene)
	return scene

func test_value_text_is_plain_total_without_a_focused_contribution() -> void:
	assert_str(LoadoutMinigame._stat_value_text(4, 0)).is_equal("4")

func test_value_text_shows_total_and_signed_gain_for_a_positive_contribution() -> void:
	# total 4, module adds +4 → "4 (+4)".
	assert_str(LoadoutMinigame._stat_value_text(4, 4)).is_equal("4 (+4)")

func test_value_text_shows_total_and_signed_loss_for_a_negative_contribution() -> void:
	# total 0, module costs −2 → "0 (−2)".
	assert_str(LoadoutMinigame._stat_value_text(0, -2)).is_equal("0 (−2)")

func test_read_only_mode_is_not_editable() -> void:
	var minigame := _minigame()
	minigame.set_mode(LoadoutMinigame.Mode.READ_ONLY)
	assert_bool(minigame._editable()).is_false()

func test_edit_mode_is_editable() -> void:
	var minigame := _minigame()
	minigame.set_mode(LoadoutMinigame.Mode.EDIT)
	assert_bool(minigame._editable()).is_true()

func test_select_mode_is_editable() -> void:
	var minigame := _minigame()
	minigame.set_mode(LoadoutMinigame.Mode.SELECT)
	assert_bool(minigame._editable()).is_true()

func test_binding_the_player_page_is_editable() -> void:
	# The player's own loadout page defaults to an editable mode (DEBUG_DEFAULT_EDIT). Mounted outside a
	# MinigameScreen, the scene self-binds a fresh game in _ready.
	var scene := _scene()
	assert_bool(scene._editable()).is_true()

func test_combat_drill_in_is_read_only() -> void:
	# show_starship is the mid-combat drill-in path, so the shown loadout is locked.
	var scene := _scene()
	scene.show_starship(GameSession.game_state.starship)
	assert_bool(scene._editable()).is_false()

func test_standalone_mount_self_binds_a_default_session() -> void:
	# The main-menu loadout route (and F6 dev-run) mount this scene on its own, with no MinigameScreen
	# to bind a session. Without a self-bind the board renders empty — the Quick Match regression. A
	# scene mounted outside a MinigameScreen must bind a fresh default game in _ready.
	var scene := _scene()
	assert_object(scene._module_grid).is_not_null()
	assert_object(scene._grid_view).is_not_null()
	assert_int(scene._module_grid.modules.size()).is_greater(0)

func test_tapping_a_module_focuses_it() -> void:
	# The tapped module becomes the focus (outlined on the board and split out of the stat totals); its
	# name is lettered on the footprint by the view, not shown in the stats panel.
	var scene := _scene()
	var module: ModuleBlueprint = GameSession.game_state.starship.module_grid.modules[0].blueprint
	scene._set_focus(module)
	assert_object(scene._focused_module).is_same(module)
