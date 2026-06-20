extends GdUnitTestSuite
## Guards the recycler's scene wiring: its panel offers craft-all ("Recycle All"), and the
## working effects are wired to wobble the model while the station works.

func test_offers_craft_all() -> void:
	var recycler := Recycler.create()
	assert_bool(recycler.allows_craft_all).is_true()
	recycler.free()

func test_working_effects_wired_to_model() -> void:
	var recycler := Recycler.create()
	var effects: WorkingEffects = recycler.get_node("WorkingEffects")
	assert_object(effects.target).is_same(recycler.get_node("Model"))
	assert_bool(recycler.work_started.is_connected(effects.start)).is_true()
	assert_bool(recycler.work_finished.is_connected(effects.stop)).is_true()
	recycler.free()
