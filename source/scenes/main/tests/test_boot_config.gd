extends GdUnitTestSuite
## Tests BootConfig — mode name table and the platform-derived default mode.

func test_mode_names_cover_both_modes() -> void:
	assert_int(BootConfig.MODE_NAMES["arcade"]).is_equal(BootConfig.Mode.ARCADE)
	assert_int(BootConfig.MODE_NAMES["game"]).is_equal(BootConfig.Mode.GAME)

func test_default_mode_matches_platform() -> void:
	# Mobile and web boot the Arcade; the test host (desktop) boots the Game.
	var expected: BootConfig.Mode = (
		BootConfig.Mode.ARCADE if OS.has_feature(FeatureTag.MOBILE) or OS.has_feature(FeatureTag.WEB)
		else BootConfig.Mode.GAME
	)
	assert_int(BootConfig.default_mode()).is_equal(expected)
