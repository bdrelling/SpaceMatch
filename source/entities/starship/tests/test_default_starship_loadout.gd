extends GdUnitTestSuite
## The default starships spawn with a loadout laid into the bay. The player default carries a Warp Core (its
## entry into warp); the computer default deliberately doesn't, so the AI can't Jump (a human PvP opponent
## would use the player default instead). Guards the authored loadouts — wired through [method Starship.create]
## from the .tres, so a broken placement or a deleted module fails here.

const _DEFAULT_STARSHIP := preload("res://data/starships/default_starship_blueprint.tres")
const _COMPUTER_STARSHIP := preload("res://data/starships/computer_default_starship_blueprint.tres")

func _default_grid() -> StarshipLoadout:
	var starship: Starship = auto_free(Starship.create(_DEFAULT_STARSHIP))
	return starship.state.loadout

func _computer_grid() -> StarshipLoadout:
	var starship: Starship = auto_free(Starship.create(_COMPUTER_STARSHIP))
	return starship.state.loadout

func test_default_starship_has_six_modules() -> void:
	var grid := _default_grid()
	assert_int(grid.modules.size()).is_equal(6)
	# shield 2 + life support 2 + reactor 4 + sensor 1 + engine 4 + warp core 1
	assert_int(grid.filled_cell_count()).is_equal(14)

func test_default_modules_sit_where_authored() -> void:
	var grid := _default_grid()
	assert_str(grid.module_at(Vector2i(2, 0)).name).is_equal("Shield Generator")
	assert_str(grid.module_at(Vector2i(2, 1)).name).is_equal("Life Support")
	assert_str(grid.module_at(Vector2i(2, 2)).name).is_equal("Reactor")
	assert_str(grid.module_at(Vector2i(4, 2)).name).is_equal("Sensor Array")
	assert_str(grid.module_at(Vector2i(2, 4)).name).is_equal("Engine")
	assert_str(grid.module_at(Vector2i(4, 3)).name).is_equal("Warp Core")

func test_default_stat_profile() -> void:
	var total := StarshipStats.new()
	for module_state: ModuleState in _default_grid().modules:
		total.add(module_state.stats)
	assert_int(total.power).is_equal(0)         # power is combat power; no default (non-weapon) module grants it
	assert_int(total.speed).is_equal(4)          # engine
	assert_int(total.shields).is_equal(4)        # shield generator
	assert_int(total.sensors).is_equal(4)        # sensor array
	assert_int(total.life_support).is_equal(5)   # life support
	assert_int(total.warp_capacity).is_equal(4)  # warp core
	assert_int(total.cargo).is_equal(0)
	assert_int(total.fuel).is_equal(0)
	assert_int(total.armor).is_equal(0)

# The starship carries its own base stat block (its hull's health), separate from modules; effective stats are
# the starship block plus the module profile. HP is starship-driven from here, not a constant.
func test_default_starship_stat_block_drives_health() -> void:
	var starship_node: Starship = auto_free(Starship.create(_DEFAULT_STARSHIP))
	var starship := starship_node.state
	assert_object(starship.base_stats).is_not_null()
	assert_int(starship.base_stats.health).is_equal(25)  # hull health lives on the starship, not a module
	var effective := starship.effective_stats()           # base stats + the loadout's module profile
	assert_int(effective.health).is_equal(25)         # starship hull
	assert_int(effective.speed).is_equal(4)           # engine module
	assert_int(effective.warp_capacity).is_equal(4)   # warp core module

# The computer default is the player default minus the Warp Core: same five base modules, no warp capacity,
# so the AI can't Jump. (A human PvP opponent would use the player default and keep its warp core.)
func test_computer_default_has_no_warp_core() -> void:
	var grid := _computer_grid()
	assert_int(grid.modules.size()).is_equal(5)
	for module_state: ModuleState in grid.modules:
		assert_str(module_state.name).is_not_equal("Warp Core")
	var total := StarshipStats.new()
	for module_state: ModuleState in grid.modules:
		total.add(module_state.stats)
	assert_int(total.warp_capacity).is_equal(0)
