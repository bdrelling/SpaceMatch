extends GdUnitTestSuite
## Uniform scale must grow a crater's footprint and depth together.

func _crater(stamp_scale: float) -> CraterStampData:
	var crater: CraterStampData = CraterStampData.new()
	crater.radius = 40.0
	crater.depth = 10.0
	crater.scale = stamp_scale
	return crater

func test_scale_grows_world_rectangle() -> void:
	var single: Rect2 = _crater(1.0).get_world_rectangle()
	var double: Rect2 = _crater(2.0).get_world_rectangle()
	assert_float(double.size.x).is_equal_approx(single.size.x * 2.0, 0.001)

func test_scale_deepens_center() -> void:
	var single: Vector2 = _crater(1.0).sample_at_world(0.0, 0.0)
	var double: Vector2 = _crater(2.0).sample_at_world(0.0, 0.0)
	assert_float(double.x).is_equal_approx(single.x * 2.0, 0.001)

func test_scaled_crater_reaches_beyond_unscaled_radius() -> void:
	# 1.2× the base radius: outside the unscaled footprint, inside the doubled one.
	assert_float(_crater(1.0).sample_at_world(48.0, 0.0).y).is_equal(0.0)
	assert_float(_crater(2.0).sample_at_world(48.0, 0.0).y).is_greater(0.0)
