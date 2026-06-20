extends GdUnitTestSuite
## Board gestures must dispatch through the minigame's own input routing — chrome
## above the board (arcade pager, screen, layout) otherwise swallows pointer
## events before _unhandled_input. A fixed-size SubViewport pins the coordinate
## space so pushed touches land where the board reports its cells.

const _VIEW_SIZE := Vector2i(1080, 1920)

func _find(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	for child: Node in node.get_children():
		var found := _find(child, type)
		if found != null:
			return found
	return null

func _host_in_viewport(scene_path: String) -> Node:
	var sub: SubViewport = auto_free(SubViewport.new())
	sub.size = _VIEW_SIZE
	add_child(sub)
	var packed: PackedScene = load(scene_path)
	var host: Node = packed.instantiate()
	sub.add_child(host)
	return host

func _press(viewport: Viewport, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = position
	viewport.push_input(event)

func _release(viewport: Viewport, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = false
	event.position = position
	viewport.push_input(event)

func _drag(viewport: Viewport, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = to
	event.relative = to - from
	viewport.push_input(event)

func test_fabricating_board_drag_dispatches() -> void:
	var fab := _host_in_viewport("res://minigames/fabricating/fabricating.tscn") as FabricatingMinigame
	await await_millis(300)
	# A recipe must be chosen before the components pour in — the picker board starts empty.
	fab._on_recipe_chosen(fab._recipes[0])
	await await_millis(1000)
	var grid: Grid = _find(fab, Grid)
	var view: MatchBoardView = _find(fab, MatchBoardView)
	assert_object(grid).is_not_null()
	assert_object(view).is_not_null()
	var transform := grid.get_global_transform()
	# Sanity: a cell's view position resolves back to that cell.
	assert_vector(Vector2(grid.cell_at(transform * grid.cell_center(Vector2i(3, 3))))).is_equal(Vector2(3, 3))
	var resolved: Array[bool] = [false]
	view.move_resolved.connect(func(_made_match: bool, _cleared: int) -> void: resolved[0] = true)
	var viewport := fab.get_viewport()
	var from_cell := Vector2i(3, 3)
	var to_cell := Vector2i(4, 3)
	var p0: Vector2 = transform * grid.cell_center(from_cell)
	var p1: Vector2 = transform * grid.cell_center(to_cell)
	_press(viewport, p0)
	await await_millis(40)
	_drag(viewport, p0, p1)
	await await_millis(40)
	_release(viewport, p1)
	# Let the committed swap and any cascade settle.
	await await_millis(1200)
	assert_bool(resolved[0]).override_failure_message(
		"Fabricating: board drag did not reach MatchBoardView (no move resolved)."
	).is_true()

func test_fabricating_tap_resolves_to_the_tapped_cell() -> void:
	# Regression: the BoardCanvas forwards _gui_input positions (local to the canvas, which sits below
	# the HUD) to the view, but cell_at resolves against the board's GLOBAL transform. Without converting
	# back to global, a press toward the top of a cell grabs the cell above it (the user's report:
	# pressing (3,3) near its top resolved to (3,2)).
	var fab := _host_in_viewport("res://minigames/fabricating/fabricating.tscn") as FabricatingMinigame
	await await_millis(300)
	# A recipe must be chosen before the components pour in — the picker board starts empty.
	fab._on_recipe_chosen(fab._recipes[0])
	await await_millis(1000)
	var grid: Grid = _find(fab, Grid)
	var view: MatchBoardView = _find(fab, MatchBoardView)
	assert_object(grid).is_not_null()
	assert_object(view).is_not_null()
	var target := Vector2i(3, 3)
	# Near the top edge but still inside the target cell — the failing case. Must grab (3,3).
	var local_point: Vector2 = grid.cell_center(target) + Vector2(0.0, -grid.cell_size * 0.45)
	var global_point: Vector2 = grid.get_global_transform() * local_point
	var viewport := fab.get_viewport()
	_press(viewport, global_point)
	await await_millis(40)
	assert_vector(Vector2(view._grab_cell)).override_failure_message(
		"Fabricating: press toward the top of cell %s grabbed %s — canvas-to-board coordinate offset." % [target, view._grab_cell]
	).is_equal(Vector2(target))
	_release(viewport, global_point)
	await await_millis(40)
