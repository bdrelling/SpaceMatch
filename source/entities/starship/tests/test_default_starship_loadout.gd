extends GdUnitTestSuite
## The default starship spawns pre-outfitted: five modules laid into its bay. Player and opponent both
## generate from this same blueprint, so they start with an identical loadout. Guards the authored
## default — wired through [StarshipGenerator] from the .tres, so a broken placement or a deleted module
## fails here.

const _DEFAULT_STARSHIP := preload("res://resources/starships/default_starship_blueprint.tres")

func _default_grid() -> ModuleGrid:
	return StarshipGenerator.generate(_DEFAULT_STARSHIP).module_grid

func test_default_ship_has_five_modules() -> void:
	var grid := _default_grid()
	assert_int(grid.placed_modules().size()).is_equal(5)
	# shield 2 + life support 2 + reactor 4 + sensor 1 + engine 4
	assert_int(grid.filled_cell_count()).is_equal(13)

func test_default_modules_sit_where_authored() -> void:
	var grid := _default_grid()
	assert_str(grid.module_at(Vector2i(2, 0)).name).is_equal("Shield Generator")
	assert_str(grid.module_at(Vector2i(2, 1)).name).is_equal("Life Support")
	assert_str(grid.module_at(Vector2i(2, 2)).name).is_equal("Reactor")
	assert_str(grid.module_at(Vector2i(4, 2)).name).is_equal("Sensor Array")
	assert_str(grid.module_at(Vector2i(2, 4)).name).is_equal("Engine")

func test_default_stat_profile() -> void:
	var total := StatBlock.new()
	for placed: PlacedModule in _default_grid().placed_modules():
		total.add(placed.module.stats)
	assert_int(total.power).is_equal(0)         # reactor +5, engine -2, shield -2, sensor -1
	assert_int(total.speed).is_equal(4)          # engine
	assert_int(total.shields).is_equal(4)        # shield generator
	assert_int(total.sensors).is_equal(4)        # sensor array
	assert_int(total.life_support).is_equal(5)   # life support
	assert_int(total.cargo).is_equal(0)
	assert_int(total.fuel).is_equal(0)
	assert_int(total.armor).is_equal(0)

func test_player_and_opponent_share_the_same_loadout() -> void:
	var player := _default_grid()
	var opponent := _default_grid()
	assert_int(opponent.placed_modules().size()).is_equal(player.placed_modules().size())
	for placed: PlacedModule in player.placed_modules():
		for cell: Vector2i in placed.cells:
			assert_str(opponent.module_at(cell).name).is_equal(placed.module.name)
