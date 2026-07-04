extends GdUnitTestSuite
## MatchConfigCatalog and the composed standard ruleset: the catalog pins the standard config, the standard
## ruleset folds in every nested fragment, and two configs sharing one ruleset resolve identical rules
## regardless of board size (a config uses a ruleset; it never owns one).


# The catalog pins the config authored in default.tres, by path, as its active fallback.
func test_active_returns_the_default_config() -> void:
	var catalog := MatchConfigCatalog.default()
	var active := catalog.active()
	assert_object(active).is_not_null()
	assert_str(active.resource_path).is_equal(MatchConfigCatalog.DEFAULT_PATH)
	assert_int(active.board_width).is_equal(8)
	assert_int(active.board_height).is_equal(8)


# The standard ruleset is a composition — one representative rule from each of the five nested fragments
# (tiles, ability resources, special tiles, turns, board) survives into the resolved set.
func test_default_ruleset_composes_every_fragment() -> void:
	var rules := RuleCatalog.default_ruleset().resolved()
	assert_bool(_any(rules, func(rule: Rule) -> bool: return rule is TileSpawnRule)).is_true()
	assert_bool(_any(rules, func(rule: Rule) -> bool: return rule is TileMatchRule)).is_true()
	assert_bool(_any(rules, func(rule: Rule) -> bool: return rule is WarpRule)).is_true()
	assert_bool(_any(rules, func(rule: Rule) -> bool: return rule is ActionBudgetRule)).is_true()
	assert_bool(_any(rules, func(rule: Rule) -> bool: return rule is BoardFillRule)).is_true()


# Two configs that reference the same ruleset resolve to the same rules whatever their board size — geometry
# is a config setting, never a rule. default.tres is 8×8, wide.tres 10×10, both on the standard ruleset.
func test_shared_ruleset_is_board_independent() -> void:
	var catalog := MatchConfigCatalog.default()
	var standard := _config_at(catalog, "res://data/match_configs/default.tres")
	var wide := _config_at(catalog, "res://data/match_configs/wide.tres")
	assert_object(standard).is_not_null()
	assert_object(wide).is_not_null()
	assert_object(wide.ruleset).is_same(standard.ruleset)
	assert_int(standard.board_width).is_equal(8)
	assert_int(wide.board_width).is_equal(10)
	assert_int(wide.ruleset.resolved().size()).is_equal(standard.ruleset.resolved().size())


# The catalog entry whose file is [param path], or null.
func _config_at(catalog: MatchConfigCatalog, path: String) -> MatchConfig:
	for config: MatchConfig in catalog.configs:
		if config != null and config.resource_path == path:
			return config
	return null


func _any(rules: Array[Rule], predicate: Callable) -> bool:
	for rule: Rule in rules:
		if predicate.call(rule):
			return true
	return false
