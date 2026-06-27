extends GdUnitTestSuite
## Board gestures must dispatch through the minigame's own input routing — the bars
## above the board (game pager, screen, layout) otherwise swallows pointer
## events before _unhandled_input. A fixed-size SubViewport pins the coordinate
## space so pushed touches land where the board reports its cells.

const _VIEW_SIZE := Vector2i(1080, 1920)
const _MATCH := "res://minigames/match/match.tscn"

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

func test_match_board_drag_dispatches() -> void:
	var match_game := _host_in_viewport(_MATCH) as MatchMinigame
	# Let _ready build the board, then wait out its pour-in intro: the board
	# ignores pointer input while it animates, so a fixed delay races the fall.
	await await_millis(100)
	var grid: Grid = _find(match_game, Grid)
	var view: MatchBoardView = _find(match_game, MatchBoardView)
	assert_object(grid).is_not_null()
	assert_object(view).is_not_null()
	await _await_board_idle(view)
	var transform := grid.get_global_transform()
	# Sanity: a cell's view position resolves back to that cell.
	assert_vector(Vector2(grid.cell_at(transform * grid.cell_center(Vector2i(3, 3))))).is_equal(Vector2(3, 3))
	var resolved: Array[bool] = [false]
	view.move_resolved.connect(func(_made_match: bool, _cleared: int) -> void: resolved[0] = true)
	var viewport := match_game.get_viewport()
	var p0: Vector2 = transform * grid.cell_center(Vector2i(3, 3))
	var p1: Vector2 = transform * grid.cell_center(Vector2i(4, 3))
	_press(viewport, p0)
	await await_millis(40)
	_drag(viewport, p0, p1)
	await await_millis(40)
	_release(viewport, p1)
	# Let the committed swap and any cascade settle.
	await await_millis(1200)
	assert_bool(resolved[0]).override_failure_message(
		"Match: board drag did not reach MatchBoardView (no move resolved)."
	).is_true()

## Waits out any in-flight board animation (the pour-in intro or a move cascade) so a
## pushed gesture isn't dropped by MatchBoardView's busy guard. Bails after ~3s.
func _await_board_idle(view: MatchBoardView) -> void:
	var waited := 0
	while view._busy and waited < 3000:
		await await_millis(50)
		waited += 50
