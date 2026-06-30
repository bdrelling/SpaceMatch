extends GdUnitTestSuite
## SpawnResourceRule + nested/resolved [Ruleset]: a spawn rule contributes its resource's tile at a weight, the
## board pool is every spawn rule composed (the match's plus a starship's, folded together), and two rules for
## the same resource merge by their combine_mode — REPLACE retunes, STACK adds. This is the generic spawn path:
## nothing keys off a resource's name and the kind set isn't a fixed count.

# A SpawnResourceRule for tile [param kind] at [param weight], merging per [param mode] on a same-resource clash.
func _spawn(kind: int, weight: int, mode: Rule.CombineMode = Rule.CombineMode.REPLACE) -> SpawnResourceRule:
	var resource := StarshipResource.new()
	resource.id = kind
	var rule := SpawnResourceRule.new()
	rule.resource = resource
	rule.weight = weight
	rule.combine_mode = mode
	return rule

func test_spawn_contribution_maps_resource_id_to_weight() -> void:
	var table: Dictionary = _spawn(3, 15).spawn_contribution()
	assert_int(table[3]).is_equal(15)

func test_non_board_resource_contributes_nothing() -> void:
	# A resource with no tile (id -1) isn't a board tile, so it adds nothing to the pool.
	assert_dict(_spawn(-1, 15).spawn_contribution()).is_empty()

func test_nested_ruleset_aggregates_into_one_pool() -> void:
	# The board pool is every spawn rule composed — here a child "spawn" set folded into a parent.
	var child := Ruleset.new()
	var child_rules: Array[Rule] = [_spawn(0, 10), _spawn(1, 7)]
	child.rules = child_rules
	var parent := Ruleset.new()
	var nested: Array[Ruleset] = [child]
	parent.rulesets = nested
	var table: Dictionary = parent.aggregate(&"spawn_contribution")
	assert_int(table[0]).is_equal(10)
	assert_int(table[1]).is_equal(7)

func test_stack_sums_same_resource_weight() -> void:
	# A starship layers a STACK spawn rule over the match's for the same tile — the weights add (10 + 5).
	var ruleset := Ruleset.new()
	var rules: Array[Rule] = [_spawn(0, 10), _spawn(0, 5, Rule.CombineMode.STACK)]
	ruleset.rules = rules
	assert_int(ruleset.aggregate(&"spawn_contribution")[0]).is_equal(15)

func test_replace_overrides_same_resource_weight() -> void:
	# REPLACE (the default) retunes instead of adding — the later rule's weight wins, not 10 + 5.
	var ruleset := Ruleset.new()
	var rules: Array[Rule] = [_spawn(0, 10), _spawn(0, 5)]
	ruleset.rules = rules
	assert_int(ruleset.aggregate(&"spawn_contribution")[0]).is_equal(5)

func test_flatten_folds_child_rulesets_before_own_rules() -> void:
	# Child sets flatten first, then the set's own rules — so a set's own rules come last and win.
	var child := Ruleset.new()
	var child_rules: Array[Rule] = [_spawn(0, 10)]
	child.rules = child_rules
	var parent := Ruleset.new()
	var nested: Array[Ruleset] = [child]
	parent.rulesets = nested
	var own_rules: Array[Rule] = [_spawn(1, 5)]
	parent.rules = own_rules
	var flat: Array[Rule] = parent.flattened()
	assert_int(flat.size()).is_equal(2)
	assert_int((flat[0] as SpawnResourceRule).resource.id).is_equal(0)
	assert_int((flat[1] as SpawnResourceRule).resource.id).is_equal(1)

func test_flatten_guards_against_a_cycle() -> void:
	# A ruleset that nests itself flattens once rather than looping forever.
	var ruleset := Ruleset.new()
	var rules: Array[Rule] = [_spawn(0, 10)]
	ruleset.rules = rules
	var nested: Array[Ruleset] = [ruleset]
	ruleset.rulesets = nested
	assert_int(ruleset.flattened().size()).is_equal(1)

func test_default_ruleset_carries_the_seven_spawn_tiles() -> void:
	# The authored default ruleset's Spawn set composes the standard pool: four stat tiles at 20, warp rarest.
	var pool: Dictionary = RuleCatalog.default_ruleset().aggregate(&"spawn_contribution")
	for stat_kind: int in 4:
		var weight: int = pool[stat_kind]
		assert_int(weight).is_equal(20)
	var warp_weight: int = pool[5]
	var stat_weight: int = pool[0]
	assert_int(warp_weight).is_less(stat_weight)  # warp rarer than any stat tile
