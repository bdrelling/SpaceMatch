extends GdUnitTestSuite
## The default starships spawn with a loadout laid into the bay. The player default carries a Warp Core (its
## entry into warp); the computer default deliberately doesn't, so the AI can't Jump (a human PvP opponent
## would use the player default instead). Guards the authored loadouts — wired through [method Starship.create]
## from the .tres, so a broken placement or a deleted module fails here.

const _DEFAULT_STARSHIP := preload("res://resources/starships/default_starship_blueprint.tres")
const _COMPUTER_STARSHIP := preload("res://resources/starships/computer_default_starship_blueprint.tres")

func _default_grid() -> ModuleGridState:
	return auto_free(Starship.create(_DEFAULT_STARSHIP)).state.module_grid

func _computer_grid() -> ModuleGridState:
	return auto_free(Starship.create(_COMPUTER_STARSHIP)).state.module_grid

func test_default_ship_has_six_modules() -> void:
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
	var total := StatBlock.new()
	for module_state: ModuleState in _default_grid().modules:
		total.add(module_state.blueprint.stats)
	assert_int(total.power).is_equal(0)         # power is combat power; no default (non-weapon) module grants it
	assert_int(total.speed).is_equal(4)          # engine
	assert_int(total.shields).is_equal(4)        # shield generator
	assert_int(total.sensors).is_equal(4)        # sensor array
	assert_int(total.life_support).is_equal(5)   # life support
	assert_int(total.warp_capacity).is_equal(4)  # warp core
	assert_int(total.cargo).is_equal(0)
	assert_int(total.fuel).is_equal(0)
	assert_int(total.armor).is_equal(0)

# The ship carries its own base stat block (its hull's health), separate from modules; effective stats are
# the ship block plus the module profile. HP is ship-driven from here, not a constant.
func test_default_ship_stat_block_drives_health() -> void:
	var starship: Starship = auto_free(Starship.create(_DEFAULT_STARSHIP))
	var ship := starship.state
	assert_object(ship.stats).is_not_null()
	assert_int(ship.stats.health).is_equal(25)  # hull health lives on the ship, not a module
	var effective := StatBlock.new()
	effective.add(ship.stats)
	effective.add(ship.module_grid.profile())
	assert_int(effective.health).is_equal(25)         # ship hull
	assert_int(effective.speed).is_equal(4)           # engine module
	assert_int(effective.warp_capacity).is_equal(4)   # warp core module

# The computer default is the player default minus the Warp Core: same five base modules, no warp capacity,
# so the AI can't Jump. (A human PvP opponent would use the player default and keep its warp core.)
func test_computer_default_has_no_warp_core() -> void:
	var grid := _computer_grid()
	assert_int(grid.modules.size()).is_equal(5)
	for module_state: ModuleState in grid.modules:
		assert_str(module_state.blueprint.name).is_not_equal("Warp Core")
	var total := StatBlock.new()
	for module_state: ModuleState in grid.modules:
		total.add(module_state.blueprint.stats)
	assert_int(total.warp_capacity).is_equal(0)
