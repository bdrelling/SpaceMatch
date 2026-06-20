extends GdUnitTestSuite
## Guards the landing flow: create() builds a ship from its blueprint, a zone reserves for
## an inbound ship and claims it on touchdown, a scene-authored child ship is adopted, and
## traffic fills an open pad at start and refills it after a departure.

const _BLUEPRINT_PATH := "res://entities/starship/starship_blueprint.tres"
const _PAD_BLUEPRINT_PATH := "res://entities/structures/landing_pad/landing_pad_blueprint.tres"

## Steps a descending ship until touchdown, capped so a regression can't hang the suite.
func _descend(zone: LandingZone) -> void:
	for i in 2000:
		if zone.occupant != null:
			return
		zone.incoming._physics_process(0.1)

func test_create_applies_blueprint() -> void:
	var blueprint: StarshipBlueprint = load(_BLUEPRINT_PATH)
	assert_object(blueprint).is_not_null()

	var ship: Starship = Starship.create(blueprint)
	assert_object(ship).is_not_null()
	assert_object(ship.blueprint).is_equal(blueprint)
	assert_object(ship.model_scene).is_equal(blueprint.model_scene)

	ship.free()

func test_zone_holds_single_occupant() -> void:
	var zone := LandingZone.new()
	var blueprint: StarshipBlueprint = load(_BLUEPRINT_PATH)
	var first: Starship = Starship.create(blueprint)
	var second: Starship = Starship.create(blueprint)

	zone.land(first)
	assert_bool(zone.is_occupied()).is_true()
	# A second landing is rejected while the zone is held.
	zone.land(second)
	assert_object(zone.occupant).is_same(first)

	assert_object(zone.depart()).is_same(first)
	assert_bool(zone.is_occupied()).is_false()
	assert_object(zone.depart()).is_null()

	zone.free()
	first.free()
	second.free()

func test_zone_adopts_scene_authored_ship() -> void:
	var zone := LandingZone.new()
	var blueprint: StarshipBlueprint = load(_BLUEPRINT_PATH)
	var ship: Starship = Starship.create(blueprint)
	zone.add_child(ship)
	add_child(zone)
	await await_idle_frame()

	assert_object(zone.occupant).is_same(ship)

	zone.queue_free()
	await await_idle_frame()

func test_receive_reserves_then_lands_on_touchdown() -> void:
	var zone := LandingZone.new()
	add_child(zone)
	var blueprint: StarshipBlueprint = load(_BLUEPRINT_PATH)
	var ship: Starship = Starship.create(blueprint)

	assert_bool(zone.receive(ship)).is_true()
	# Mid-approach: reserved (not available) but not yet occupied, ship parked high above.
	assert_object(zone.incoming).is_same(ship)
	assert_object(zone.occupant).is_null()
	assert_bool(zone.is_available()).is_false()
	assert_float(ship.global_position.y).is_greater(zone.global_position.y + 100.0)

	# A second arrival is rejected while one is inbound.
	var second: Starship = Starship.create(blueprint)
	assert_bool(zone.receive(second)).is_false()

	_descend(zone)
	assert_object(zone.occupant).is_same(ship)
	assert_object(zone.incoming).is_null()
	assert_vector(ship.global_position).is_equal_approx(zone.global_position, Vector3.ONE * 0.01)

	second.free()
	zone.queue_free()
	await await_idle_frame()

func test_traffic_fills_pad_and_refills_after_departure() -> void:
	var pad_blueprint: LandingPadBlueprint = load(_PAD_BLUEPRINT_PATH)
	var pad: LandingPad = LandingPad.create(pad_blueprint)
	add_child(pad)

	var traffic := StarshipTraffic.new()
	traffic.landing_pads.append(pad)
	var blueprint: StarshipBlueprint = load(_BLUEPRINT_PATH)
	traffic.fleet.append(blueprint)
	add_child(traffic)
	await await_idle_frame()

	# Game start: the open pad immediately gets an arrival.
	assert_bool(pad.is_available()).is_false()
	assert_object(pad.landing_zone.incoming).is_not_null()

	_descend(pad.landing_zone)
	assert_bool(pad.landing_zone.is_occupied()).is_true()

	# Departure frees the pad and traffic refills it immediately.
	var departed: Starship = pad.landing_zone.depart()
	assert_object(departed).is_not_null()
	departed.queue_free()
	assert_object(pad.landing_zone.incoming).is_not_null()
	assert_object(pad.landing_zone.incoming).is_not_same(departed)

	traffic.queue_free()
	pad.queue_free()
	await await_idle_frame()
