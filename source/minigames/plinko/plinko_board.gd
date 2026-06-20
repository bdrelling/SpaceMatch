class_name PlinkoBoard
extends Node2D
## Plinko field for the recycling minigame: scrap balls tumble through pegs into one of three slots.
## A ball landing in a slot pays that slot's component and, unless the player has locked it, changes
## the slot's type. Lock all three on the same type to match them and win the rare damaged-module
## jackpot. A scrap marker slides across the top; the host drops it on tap. Drawn from its own (0, 0)
## origin and mounted on a [BoardCanvas].

const BOARD_SIZE := Vector2(720.0, 1040.0)

const _SLOT_COUNT := 3
const _MODULE_OUTPUT := 3
const _PEG_ROWS := 8
const _PEG_COLUMNS := 7
const _PEG_RADIUS := 9.0
const _PEG_TOP := 150.0
const _PEG_ROW_SPACING := 84.0
const _WALL_THICKNESS := 10.0
const _TRAY_HEIGHT := 200.0
const _FLOOR_THICKNESS := 16.0
const _DIVIDER_THICKNESS := 10.0
const _DESPAWN_MARGIN := 300.0
const _DROP_Y := 36.0
const _DROP_SPEED := 340.0
const _MARKER_RADIUS := 16.0

## A landed ball paid its slot's component.
signal recycled(output: ItemStack)
## All three slots matched on one type — the damaged-module payout.
signal jackpot(output: ItemStack)

var _ball_container: Node2D
var _slots: Array[PlinkoSlot] = []
var _samples: Array[ItemStack] = []
var _drop_x: float = BOARD_SIZE.x * 0.5
var _drop_direction: float = 1.0

## Builds the pegs, walls, and the three slots. [param samples] (a recipe's ordered output stacks)
## tints the slot types; the produced item comes from each ball's own outputs.
func build(samples: Array[ItemStack]) -> void:
	_samples = samples
	_ball_container = Node2D.new()
	_ball_container.name = "Balls"
	_build_bounds()
	_build_pegs()
	_build_slots()
	add_child(_ball_container)

## Drops [param count] balls at the marker's current position, each carrying [param outputs] (the
## feeding scrap's ordered recycle outputs).
func drop_balls(count: int, outputs: Array[ItemStack]) -> void:
	if _ball_container == null:
		return
	for i: int in range(count):
		var ball := PlinkoBall.create(outputs)
		ball.position = Vector2(_drop_x, _DROP_Y - float(i) * 34.0)
		_ball_container.add_child(ball)

## Whether [param global_point] is over the board at all (vs the framed margins around it).
func contains_global(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	return local.x >= 0.0 and local.x <= BOARD_SIZE.x and local.y >= 0.0 and local.y <= BOARD_SIZE.y

## Index of the slot under [param global_point], or -1 when the point is not over a slot.
func slot_index_at(global_point: Vector2) -> int:
	var local := to_local(global_point)
	for i: int in range(_slots.size()):
		if _slots[i].contains_point(local):
			return i
	return -1

## Locks/unlocks the slot at [param index] — the player's lock action.
func lock_slot(index: int) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index].toggle_lock()

func _process(delta: float) -> void:
	var min_x := _WALL_THICKNESS + _MARKER_RADIUS + 8.0
	var max_x := BOARD_SIZE.x - _WALL_THICKNESS - _MARKER_RADIUS - 8.0
	_drop_x += _drop_direction * _DROP_SPEED * delta
	if _drop_x >= max_x:
		_drop_x = max_x
		_drop_direction = -1.0
	elif _drop_x <= min_x:
		_drop_x = min_x
		_drop_direction = 1.0
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if _ball_container == null:
		return
	for child: Node in _ball_container.get_children():
		var ball := child as PlinkoBall
		if ball != null and ball.position.y > BOARD_SIZE.y + _DESPAWN_MARGIN:
			ball.queue_free()

func _build_bounds() -> void:
	var bounds := StaticBody2D.new()
	bounds.name = "Bounds"
	_add_rect(bounds, Rect2(0.0, 0.0, _WALL_THICKNESS, BOARD_SIZE.y))
	_add_rect(bounds, Rect2(BOARD_SIZE.x - _WALL_THICKNESS, 0.0, _WALL_THICKNESS, BOARD_SIZE.y))
	_add_rect(bounds, Rect2(0.0, BOARD_SIZE.y - _FLOOR_THICKNESS, BOARD_SIZE.x, _FLOOR_THICKNESS))
	var slot_width := BOARD_SIZE.x / float(_SLOT_COUNT)
	for i: int in range(_SLOT_COUNT + 1):
		var x := float(i) * slot_width - _DIVIDER_THICKNESS * 0.5
		_add_rect(bounds, Rect2(x, BOARD_SIZE.y - _TRAY_HEIGHT, _DIVIDER_THICKNESS, _TRAY_HEIGHT))
	add_child(bounds)

func _add_rect(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)

func _build_pegs() -> void:
	var usable_width := BOARD_SIZE.x - _WALL_THICKNESS * 2.0 - 40.0
	var spacing := usable_width / float(_PEG_COLUMNS - 1)
	for row: int in range(_PEG_ROWS):
		var stagger := spacing * 0.5 if row % 2 == 1 else 0.0
		var y := _PEG_TOP + float(row) * _PEG_ROW_SPACING
		for col: int in range(_PEG_COLUMNS):
			var x := _WALL_THICKNESS + 20.0 + float(col) * spacing + stagger
			if x <= _WALL_THICKNESS + _PEG_RADIUS or x >= BOARD_SIZE.x - _WALL_THICKNESS - _PEG_RADIUS:
				continue
			var peg := PlinkoPeg.create(_PEG_RADIUS)
			peg.position = Vector2(x, y)
			add_child(peg)

func _build_slots() -> void:
	var slot_width := BOARD_SIZE.x / float(_SLOT_COUNT)
	var slot_height := _TRAY_HEIGHT - _FLOOR_THICKNESS
	for i: int in range(_SLOT_COUNT):
		var slot := PlinkoSlot.create(slot_width - _DIVIDER_THICKNESS, slot_height, _samples)
		slot.output_index = i  # start on different types so the board isn't pre-matched
		slot.position = Vector2((float(i) + 0.5) * slot_width, BOARD_SIZE.y - _TRAY_HEIGHT + slot_height * 0.5)
		slot.ball_landed.connect(_on_slot_ball_landed)
		add_child(slot)
		_slots.append(slot)

func _on_slot_ball_landed(slot: PlinkoSlot, ball: PlinkoBall) -> void:
	if not slot.locked:
		slot.change_type()
	var component: ItemStack = ball.outputs[slot.output_index] if slot.output_index < ball.outputs.size() else null
	var module: ItemStack = ball.outputs[_MODULE_OUTPUT] if ball.outputs.size() > _MODULE_OUTPUT else null
	if component != null:
		recycled.emit(component)
	ball.queue_free()
	if _matched() and module != null:
		jackpot.emit(module)
		_reset_round()

func _matched() -> bool:
	if _slots.is_empty():
		return false
	var first := _slots[0].output_index
	for slot: PlinkoSlot in _slots:
		if slot.output_index != first:
			return false
	return true

func _reset_round() -> void:
	for slot: PlinkoSlot in _slots:
		slot.unlock()
		slot.change_type()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color(0.12, 0.13, 0.16), true)
	draw_circle(Vector2(_drop_x, _DROP_Y), _MARKER_RADIUS, Color(0.78, 0.72, 0.6))
