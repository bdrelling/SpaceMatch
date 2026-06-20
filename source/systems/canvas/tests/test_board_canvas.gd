extends GdUnitTestSuite
## Fit-and-center math on [[BoardCanvas]] (the pinch/pan gestures are
## validated visually in the demos).

func _make_canvas(canvas_size: Vector2) -> BoardCanvas:
	var canvas: BoardCanvas = auto_free(BoardCanvas.new())
	canvas.padding = 20.0
	add_child(canvas)
	canvas.size = canvas_size
	return canvas

func test_fits_and_centers_board() -> void:
	# 560x760 usable after padding; height is the tighter axis: 760 / 640 = 1.1875.
	var canvas := _make_canvas(Vector2(600, 800))
	var board := Node2D.new()
	canvas.set_board(board, Vector2(400, 640))
	assert_float(board.scale.x).is_equal_approx(1.1875, 0.001)
	assert_float(board.position.x).is_equal_approx(62.5, 0.01)
	assert_float(board.position.y).is_equal_approx(20.0, 0.01)

func test_fit_is_limited_by_width_for_wide_boards() -> void:
	# A board wider than it is tall fits to width: 560 / 800 = 0.7.
	var canvas := _make_canvas(Vector2(600, 800))
	var board := Node2D.new()
	canvas.set_board(board, Vector2(800, 200))
	assert_float(board.scale.x).is_equal_approx(0.7, 0.001)
	assert_float(board.position.x).is_equal_approx(20.0, 0.01)
	assert_float(board.position.y).is_equal_approx(330.0, 0.01)

func test_recenter_restores_centered_position() -> void:
	var canvas := _make_canvas(Vector2(600, 800))
	var board := Node2D.new()
	canvas.set_board(board, Vector2(400, 640))
	board.position = Vector2(999, 999)
	canvas.recenter()
	assert_float(board.position.x).is_equal_approx(62.5, 0.01)
	assert_float(board.position.y).is_equal_approx(20.0, 0.01)

func test_non_interactive_canvas_ignores_zoom() -> void:
	# Default (interactive == false): the board is locked to its fit-and-centered framing — a zoom
	# gesture must not move it.
	var canvas := _make_canvas(Vector2(600, 800))
	var board := Node2D.new()
	canvas.set_board(board, Vector2(400, 640))
	var fit_scale: float = board.scale.x
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(300, 400)
	canvas._gui_input(wheel)
	assert_float(board.scale.x).is_equal_approx(fit_scale, 0.001)

func _touch(pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	return event

func _left_button(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event

func test_emulated_mouse_from_touch_is_dropped() -> void:
	# The regression behind "refurbishing doesn't work on touch": one physical tap reaches the canvas
	# as the raw touch and then a left-button mouse the OS emulates from it — with the emulated press
	# landing after the finger lifts. The touch must pass through and the whole emulated pair must drop,
	# so a press-driven toggle downstream (the placement tray) doesn't fire twice per tap.
	var canvas := BoardCanvas.new()
	assert_bool(canvas._is_emulated_pointer(_touch(true))).is_false()
	assert_bool(canvas._is_emulated_pointer(_touch(false))).is_false()
	assert_bool(canvas._is_emulated_pointer(_left_button(true))).override_failure_message(
		"The mouse press the OS emulates from a touch must be dropped, even after the touch released."
	).is_true()
	assert_bool(canvas._is_emulated_pointer(_left_button(false))).is_true()
	# Once that emulated pair is consumed, a genuine later mouse press passes through again.
	assert_bool(canvas._is_emulated_pointer(_left_button(true))).is_false()
	canvas.free()

func test_genuine_mouse_passes_through_without_touch() -> void:
	# Desktop: no touch ever arms the guard, so every mouse event reaches the board.
	var canvas := BoardCanvas.new()
	assert_bool(canvas._is_emulated_pointer(_left_button(true))).is_false()
	assert_bool(canvas._is_emulated_pointer(_left_button(false))).is_false()
	canvas.free()
