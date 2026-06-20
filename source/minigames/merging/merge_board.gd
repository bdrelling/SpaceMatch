class_name MergeBoard
extends Node2D
## Suika-style merge field: items fall into a walled bin and two on the same tier fuse into the next
## one up. An aimer rides the top rail; the host nudges it with the pointer and taps to drop. Once the
## bin settles, any item whose centre sits above the danger line ends the run.
##
## The host sizes the board to its canvas and mounts it unscaled, so the physics items and the drawn bin
## live in the same space — an item is the same fraction of the bin width on every screen. Geometry
## constants are authored against [constant REFERENCE_SIZE] and scaled to the live [member size].

## Layout the constants below are authored against; the live board scales them by [member size].x / this.
const REFERENCE_SIZE := Vector2(720.0, 1040.0)

## The two PVP players, each identified by the ring color drops carry; turns alternate between them.
const PLAYER_RED := Color(0.93, 0.30, 0.31)
const PLAYER_BLUE := Color(0.34, 0.56, 0.95)
const _NO_OWNER := Color(0.0, 0.0, 0.0, 0.0)

const _WALL_THICKNESS := 16.0
const _DROP_Y := 70.0
const _DANGER_Y := 150.0
const _DROP_IMPULSE_SPEED := 700.0
const _SETTLED_SPEED := 24.0

## A pair fused; [param tier] is the rung they were on, [param points] what it scored.
signal merged(tier: int, points: int)
signal score_changed(score: int)
## The bin settled with an item's centre above the danger line — the run is over.
signal game_over()

var tiers: Array[MergeItemBlueprint] = []
var score: int = 0
var alive: bool = true
## When true, drops alternate between the two player colors and merges take an owner (see [method _merged_owner]).
var pvp: bool = false
## The board's pixel size, set by [method build] to the host's canvas so the board renders 1:1.
var size: Vector2 = REFERENCE_SIZE

var _items: Node2D
# The frozen item sitting on the launcher — the same body that [method drop] releases, so the preview
# is literally what falls.
var _held: MergeItem
# The dropped item that has not touched anything yet; blocks the next drop until it lands.
var _pending: MergeItem
var _aim_x: float = REFERENCE_SIZE.x * 0.5
var _current_tier: int = 0
var _next_tier: int = 0
# Highest tier the dropper spawns; the bigger tiers are earned by merging.
var _max_drop_tier: int = 0
# size.x / REFERENCE_SIZE.x — scales the authored geometry (and gravity) to the live board.
var _unit: float = 1.0
# Whose turn it is to drop (the held item's color); flips each drop in PVP.
var _held_player: Color = PLAYER_RED
# The player who dropped the ball currently resolving — the color a split merge goes to.
var _active_player: Color = PLAYER_RED
var _random := RandomNumberGenerator.new()

## Builds the bin and seeds the first two drops. [param ladder] is the tier list (low to high), with
## radii already in [param board_size]'s space; a non-zero [param board_seed] makes the sequence
## reproducible.
func build(ladder: Array[MergeItemBlueprint], board_seed: int = 0, max_drop_tier: int = 0, board_size: Vector2 = REFERENCE_SIZE) -> void:
	tiers = ladder
	_max_drop_tier = max_drop_tier
	size = board_size
	_unit = size.x / REFERENCE_SIZE.x
	_aim_x = size.x * 0.5
	if board_seed != 0:
		_random.seed = board_seed
	else:
		_random.randomize()
	_items = Node2D.new()
	_items.name = "Items"
	_build_walls()
	add_child(_items)
	_held_player = PLAYER_RED
	_active_player = PLAYER_RED
	_current_tier = _roll_drop_tier()
	_next_tier = _roll_drop_tier()
	_spawn_held()
	queue_redraw()

## Slides the held item along the launcher to [param global_point]'s x, clamped within the walls.
func aim_to_global(global_point: Vector2) -> void:
	var local := to_local(global_point)
	var radius := _held.blueprint.radius if _held != null else _tier_radius(_current_tier)
	_aim_x = clampf(local.x, _wall() + radius, size.x - _wall() - radius)
	if _held != null:
		_held.position.x = _aim_x
	queue_redraw()

## Releases the held item into the bin and brings up the next one. Blocked while a previously dropped
## item is still falling (hasn't touched anything yet) or once the run is over.
func drop() -> void:
	if not alive or _pending != null or _held == null:
		return
	var ball := _held
	_held = null
	_pending = ball
	# The ball now falling — and any merges it triggers — belongs to the player who just dropped it.
	_active_player = _held_player
	ball.release(_DROP_IMPULSE_SPEED * _unit)
	ball.body_entered.connect(_on_item_contact.bind(ball))
	_current_tier = _next_tier
	_next_tier = _roll_drop_tier()
	if pvp:
		_held_player = _other_player(_held_player)
	_spawn_held()
	queue_redraw()

# Brings up the next item, frozen on the launcher at the current aim.
func _spawn_held() -> void:
	if tiers.is_empty():
		return
	_held = MergeItem.create(_current_tier, tiers[_current_tier], _unit)
	_held.owner_color = _held_player if pvp else _NO_OWNER
	_held.hold()
	_held.position = Vector2(_aim_x, _drop_y())
	_items.add_child(_held)

## The tier the next [method drop] will spawn.
func current_drop_tier() -> int:
	return _current_tier

## The tier queued after the current one — the host's "up next" preview.
func next_drop_tier() -> int:
	return _next_tier

## Whose turn it is to drop, as the player's color. Always [constant PLAYER_RED] outside PVP.
func current_player() -> Color:
	return _held_player

## Whether [param global_point] is over the bin at all (vs the framed margins around it).
func contains_global(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	return local.x >= 0.0 and local.x <= size.x and local.y >= 0.0 and local.y <= size.y

## Clears the bin and starts a fresh run.
func reset() -> void:
	if _items != null:
		for child: Node in _items.get_children():
			child.queue_free()
	_held = null
	_pending = null
	score = 0
	alive = true
	_held_player = PLAYER_RED
	_active_player = PLAYER_RED
	_current_tier = _roll_drop_tier()
	_next_tier = _roll_drop_tier()
	_spawn_held()
	score_changed.emit(score)
	queue_redraw()

func _on_item_contact(other_body: Node, item: MergeItem) -> void:
	# The dropped item touched something — release the drop lock so the next one can fall.
	if _pending != null and (item == _pending or other_body == _pending):
		_pending = null
	var other := other_body as MergeItem
	if other == null or item.consumed or other.consumed or other.tier != item.tier:
		return
	# Resolve the merge deferred — adding/freeing physics bodies inside a contact callback throws
	# "Can't change this state while flushing queries". Deferred calls also run in order, so the second
	# (mirrored) contact finds the pair already consumed and no-ops.
	_merge.call_deferred(item, other)

# Fuses [param a] and [param b] into one item a tier higher at their midpoint; the top tier just
# clears instead. Returns the promoted item, or null when the pair was topped out or already consumed.
func _merge(a: MergeItem, b: MergeItem) -> MergeItem:
	if not is_instance_valid(a) or not is_instance_valid(b) or a.consumed or b.consumed:
		return null
	a.consumed = true
	b.consumed = true
	var midpoint := (a.position + b.position) * 0.5
	var tier := a.tier
	a.queue_free()
	b.queue_free()
	var points := tier + 1
	score += points
	merged.emit(tier, points)
	score_changed.emit(score)
	if tier + 1 >= tiers.size():
		return null
	var promoted := MergeItem.create(tier + 1, tiers[tier + 1], _unit)
	promoted.owner_color = _merged_owner(a, b)
	promoted.position = midpoint
	promoted.body_entered.connect(_on_item_contact.bind(promoted))
	_items.add_child(promoted)
	return promoted

func _physics_process(_delta: float) -> void:
	# Belt-and-braces: if the board is ever mounted scaled, counter it on the frozen held item so it
	# matches the simulated (unscaled) items. At the host's 1:1 mount this is a no-op.
	if _held != null and scale.x > 0.0:
		_held.scale = Vector2.ONE / scale.x
	if not alive or _items == null:
		return
	# Lose only once everything is at rest: if any settled item's centre is above the danger line (more
	# than half the item poking over the top), the run ends. A still-falling item never triggers it.
	var all_settled := _pending == null
	var breached := false
	for child: Node in _items.get_children():
		var item := child as MergeItem
		if item == null or item == _held or item.consumed:
			continue
		if item.linear_velocity.length() > _SETTLED_SPEED * _unit:
			all_settled = false
			break
		if item.position.y < _danger_y():
			breached = true
	if all_settled and breached:
		alive = false
		game_over.emit()
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.14), true)
	draw_line(Vector2(_wall(), _danger_y()), Vector2(size.x - _wall(), _danger_y()), Color(0.7, 0.3, 0.3, 0.45), 2.0)
	if not alive:
		return
	# A guide line marking where the held item will fall. The held item itself draws as a real body.
	draw_line(Vector2(_aim_x, _drop_y()), Vector2(_aim_x, size.y - _wall()), Color(1.0, 1.0, 1.0, 0.1), 2.0)

func _wall() -> float:
	return _WALL_THICKNESS * _unit

func _drop_y() -> float:
	return _DROP_Y * _unit

func _danger_y() -> float:
	return _DANGER_Y * _unit

func _roll_drop_tier() -> int:
	var top := mini(_max_drop_tier, tiers.size() - 1)
	return _random.randi_range(0, maxi(0, top))

# The owner a fused pair promotes to: a matched pair keeps its shared color, a split (one of each) goes
# to the player whose drop is resolving. Outside PVP both owners are transparent, so this returns that.
func _merged_owner(a: MergeItem, b: MergeItem) -> Color:
	if a.owner_color == b.owner_color:
		return a.owner_color
	return _active_player

func _other_player(player: Color) -> Color:
	return PLAYER_RED if player == PLAYER_BLUE else PLAYER_BLUE

func _tier_radius(tier: int) -> float:
	if tier < 0 or tier >= tiers.size():
		return 24.0 * _unit
	return tiers[tier].radius

func _build_walls() -> void:
	var bounds := StaticBody2D.new()
	bounds.name = "Bounds"
	var wall := _wall()
	_add_rect(bounds, Rect2(0.0, 0.0, wall, size.y))
	_add_rect(bounds, Rect2(size.x - wall, 0.0, wall, size.y))
	_add_rect(bounds, Rect2(0.0, size.y - wall, size.x, wall))
	add_child(bounds)

func _add_rect(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)
