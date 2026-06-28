class_name MatchGravity
extends Node2D
## The "unlock" mechanic: rips the [[MatchTile]]s off the [[Grid]] and lets real physics take over. Each
## tile becomes a [RigidBody2D] with a collider cut to its glyph's silhouette, gravity switches on, and
## they drop into a heap behind the board walls. Matching no longer runs on grid lines — it runs on
## physical contact: three-or-more touching tiles of one kind pop. The logical board ([[GridState]])
## keeps running underneath as pure bookkeeping, so every pop clears those cells and a normal refill rolls
## fresh tiles in at the top, which then fall into the pile. The grid is forever quietly refilling under
## the chaos. Prototype-grade — meant to answer "does this feel good," not to starship.
##
## This is a SpaceMatch-only effect; matchbox knows nothing about physics. It mounts as an unscaled
## overlay sized to the board's CURRENT on-screen rectangle (so a tile here is the same size it was on the
## board) and works in those screen pixels. Running unscaled matters: Godot ignores node scale on polygon
## colliders, so a scaled space would collide wrong. The host hands us the board's display scale and we
## bake it into one effective cell size.

const _MIN_RUN: int = 3
## Glyph half-extent in cell units, matching [constant MatchTile._HALF]. Used by the fallback collider
## for kinds without baked art.
const _HALF: float = 0.40
## Sprite-traced collision outlines, one per art kind, in unit cell-space. See [TileCollisionSet].
const _COLLISION_SET: TileCollisionSet = preload("res://minigames/match/tile_collision_set.tres")
## Wall thickness (px) and how far the side walls rise above the board to corral a tall pile.
const _WALL: float = 40.0
const _CEILING_RISE: float = 1024.0
## Settle gate. The pile must hold still — every body below [constant _ANGULAR_STILL] and a per-cell
## linear threshold — for [constant _CALM_NEEDED] continuous seconds before matches are evaluated, so a
## cluster of four-or-more gets a chance to form instead of popping the instant three touch. A jittery
## pile that never fully stills is force-resolved after [constant _MAX_WAIT] so it never drags on.
const _CALM_NEEDED: float = 0.18
const _MAX_WAIT: float = 2.5
const _ANGULAR_STILL: float = 1.0
## Unlock burst. On release each tile is flung outward from the board centre with a tumble — an
## explosion, not a limp drop — and then a heavier-than-default [member RigidBody2D.gravity_scale]
## yanks the heap down so it still settles fast. The blast is biased outward-and-down (never up, since
## the top is open) so the scatter stays corralled within the board walls.
const _BURST_SPEED_MIN: float = 5.0  # outward kick, in cell-units/sec
const _BURST_SPEED_MAX: float = 11.0
const _BURST_SPIN: float = 7.0       # random tumble, rad/sec
const _GRAVITY_SCALE: float = 1.8
## Pop animation, mirroring the board's match pop ([code]MatchBoardView._animate_pop[/code]).
const _POP_SCALE: float = 1.5
const _POP_DURATION: float = 0.13

var _cell_size: float = 64.0
var _columns: int = 0
var _rows: int = 0
var _session: GridSession
var _state: GridState
## `func(state: GridState, cell: Vector2i) -> GridObjectState` — the host's refill factory, reused
## verbatim so spawned kinds stay equal-frequency.
var _spawn_cb: Callable
var _material: PhysicsMaterial

## Board display scale folded into one screen-pixel cell size; set at unlock from the host.
var _eff_cell: float = 64.0
var _active: bool = false
var _idle: bool = false  # settled with nothing left to match; rests until disturbed again
var _calm: float = 0.0  # continuous seconds the whole pile has been still
var _since_resolve: float = 0.0  # seconds since unlock or the last pop, for the force-resolve cap
# RigidBody2D -> _Body. Snapshot .keys() before mutating; queue_free defers, so refs stay live this tick.
var _by_body: Dictionary = {}

## One physical tile: its body, its glyph node, its kind, and the logical board object it stands in for.
class _Body:
	var body: RigidBody2D
	var tile: MatchTile
	var kind: int
	var object: GridObjectState

func setup(cell_size: float, columns: int, rows: int, session: GridSession, spawn_cb: Callable) -> void:
	_cell_size = cell_size
	_columns = columns
	_rows = rows
	_session = session
	_spawn_cb = spawn_cb
	_material = PhysicsMaterial.new()
	_material.friction = 0.9
	_material.bounce = 0.0
	set_physics_process(false)

## True once the board has been unlocked into physics.
func is_active() -> bool:
	return _active

## Switches gravity on. [param grid] is the live board (we steal its tiles); [param display_scale] is the
## board's current on-screen scale, which we bake into the overlay so tiles keep their size. Idempotent.
func unlock(grid: Grid, display_scale: float) -> void:
	if _active:
		return
	_active = true
	_state = _session.state
	_eff_cell = _cell_size * display_scale
	_build_walls()
	for child: Node in grid.get_children():
		var tile := child as MatchTile
		if tile == null:
			continue
		# Tile position is its cell centre in board-local px; floor recovers the cell, ×scale gives the
		# matching point in our screen-pixel overlay.
		var local_position: Vector2 = tile.position
		var cell := Vector2i(floori(local_position.x / _cell_size), floori(local_position.y / _cell_size))
		var object: GridObjectState = _state.get_object_at(0, cell.x, cell.y)
		# Detach from the grid without freeing, and drop the registry entry so a stray reflow can't yank
		# the tile back or free it out from under its body.
		grid.remove_child(tile)
		grid._tiles.erase(tile)
		_attach_body(tile, tile.kind, object, local_position * display_scale)
	_burst_bodies()
	set_physics_process(true)

# Fling the freshly-detached tiles outward from the board centre with a tumble so the unlock reads as
# an explosion rather than a drop. Vertical is forced downward (the top is open, so an upward kick would
# fountain past it) while horizontal keeps each tile's outward direction — the scatter stays in the walls.
func _burst_bodies() -> void:
	var center := Vector2(_columns * _eff_cell, _rows * _eff_cell) * 0.5
	for body: RigidBody2D in _by_body.keys():
		var direction: Vector2 = body.position - center
		if direction.length() < 1.0:
			direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		direction.y = absf(direction.y) * 0.4 + 0.2
		direction = direction.normalized()
		body.linear_velocity = direction * randf_range(_BURST_SPEED_MIN, _BURST_SPEED_MAX) * _eff_cell
		body.angular_velocity = randf_range(-_BURST_SPIN, _BURST_SPIN)

func _physics_process(delta: float) -> void:
	if not _active or _idle:
		return
	# Let the pile fall and settle, THEN match — so fours-and-up form. Force a pass if it never quite
	# stills. A pop (and its refill drop) disturbs the pile, so we wait it out and resolve again; when a
	# settled pile has nothing left to match, we go idle and rest.
	_since_resolve += delta
	_calm = _calm + delta if _all_still() else 0.0
	if _calm < _CALM_NEEDED and _since_resolve < _MAX_WAIT:
		return
	var popped: bool = _resolve_matches()
	_calm = 0.0
	_since_resolve = 0.0
	if not popped:
		_idle = true

# --- matching ---

# True when every body has all but stopped — the settle test. Linear threshold scales with cell size so
# it reads "barely creeping" at any board scale.
func _all_still() -> bool:
	var still_speed: float = _eff_cell * 0.25
	for body: RigidBody2D in _by_body.keys():
		if body.linear_velocity.length() > still_speed or absf(body.angular_velocity) > _ANGULAR_STILL:
			return false
	return true

# Flood the contact graph (same-kind only) into clusters; pop clusters of three-or-more, clear their
# logical cells, then refill those cells with tiles that drop in from the top. Returns true if anything
# popped (so the caller knows the pile was disturbed and another settle/resolve cycle is coming).
func _resolve_matches() -> bool:
	var visited: Dictionary = {}
	var emptied: Array[Vector2i] = []
	for body: RigidBody2D in _by_body.keys():
		if visited.has(body):
			continue
		var seed_rec: _Body = _by_body[body]
		var cluster: Array[_Body] = []
		var stack: Array[_Body] = [seed_rec]
		visited[body] = true
		while not stack.is_empty():
			var current: _Body = stack.pop_back()
			cluster.append(current)
			for other: Node in current.body.get_colliding_bodies():
				var neighbour: _Body = _by_body.get(other)
				if neighbour == null or neighbour.kind != current.kind or visited.has(other):
					continue
				visited[other] = true
				stack.append(neighbour)
		if cluster.size() >= _MIN_RUN:
			for rec: _Body in cluster:
				if rec.object != null:
					_state.remove_object(0, rec.object)
					emptied.append(rec.object.cells[0])
				_by_body.erase(rec.body)
				_pop_tile(rec.tile, rec.body)
	if emptied.is_empty():
		return false
	_refill(emptied)
	return true

# Roll a fresh object into each cleared cell (logical bookkeeping, keeps the board at 64) and drop its
# body in as one batch scattered across the top — natural physics fall, not a column-locked trickle.
func _refill(emptied: Array[Vector2i]) -> void:
	var bin_width: float = _columns * _eff_cell
	var margin: float = _eff_cell * 0.5
	for cell: Vector2i in emptied:
		if _state.get_object_at(0, cell.x, cell.y) != null:
			continue
		var object: GridObjectState = _spawn_cb.call(_state, cell)
		if object == null:
			continue
		_state.place_object(0, object)
		# Scatter across the width, just above the top edge; a little vertical spread keeps a batch from
		# spawning on top of itself.
		var spawn := Vector2(randf_range(margin, bin_width - margin), -randf_range(1.0, 2.5) * _eff_cell)
		var kind: int = object.state.get("kind", 0)
		var tile := MatchTile.new()
		tile.kind = kind
		_attach_body(tile, kind, object, spawn)

# --- bodies ---

# The board's match pop, in the heap: lift the glyph out of its body so the body's collision can die at
# once (tiles resting on it collapse into the gap), then scale it up and fade it out before freeing.
func _pop_tile(tile: MatchTile, body: RigidBody2D) -> void:
	tile.reparent(self)
	body.queue_free()
	var tween: Tween = tile.create_tween().set_parallel(true)
	tween.tween_property(tile, "scale", tile.scale * _POP_SCALE, _POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "modulate:a", 0.0, _POP_DURATION).set_ease(Tween.EASE_IN)
	tween.finished.connect(tile.queue_free)

func _attach_body(tile: MatchTile, kind: int, object: GridObjectState, position: Vector2) -> void:
	var body := RigidBody2D.new()
	body.position = position
	body.physics_material_override = _material
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.gravity_scale = _GRAVITY_SCALE
	body.linear_damp = 0.3
	body.angular_damp = 0.5
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	add_child(body)
	body.add_child(_collider_for(kind))
	# Re-centre the glyph on the body origin and scale it to our screen-pixel cell so it matches the size
	# it had on the board.
	tile.position = Vector2.ZERO
	tile.rotation = 0.0
	tile.scale = Vector2(_eff_cell, _eff_cell)
	body.add_child(tile)
	var rec := _Body.new()
	rec.body = body
	rec.tile = tile
	rec.kind = kind
	rec.object = object
	_by_body[body] = rec

# A collider cut to the kind's sprite silhouette so shapes interlock as they pile. The outline is
# traced from the tile art (see [TileCollisionSet]) and scaled to our effective cell; build_mode SOLIDS
# lets the physics server convex-decompose a concave silhouette. Kinds without baked art (damage) fall
# back to a plain pentagon.
func _collider_for(kind: int) -> Node2D:
	var poly := CollisionPolygon2D.new()
	poly.polygon = _outline_for(kind)
	return poly

func _outline_for(kind: int) -> PackedVector2Array:
	var baked: PackedVector2Array = _COLLISION_SET.outline_for(kind)
	if not baked.is_empty():
		var scaled := PackedVector2Array()
		for point: Vector2 in baked:
			scaled.append(point * _eff_cell)
		return scaled
	# No art for this kind — a plain pentagon stands in.
	return _ngon(5, _HALF * _eff_cell, -PI / 2.0)

func _ngon(sides: int, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in sides:
		var angle: float = rotation + index * TAU / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

# Floor plus two tall side walls; no ceiling, so refills fall in from above. Side walls rise past the
# board top to keep a high pile corralled.
func _build_walls() -> void:
	var board_w: float = _columns * _eff_cell
	var board_h: float = _rows * _eff_cell
	var tall: float = board_h + _CEILING_RISE
	var mid_y: float = board_h - tall * 0.5
	_add_wall(Vector2(board_w * 0.5, board_h + _WALL * 0.5), Vector2(board_w + _WALL * 2.0, _WALL))
	_add_wall(Vector2(-_WALL * 0.5, mid_y), Vector2(_WALL, tall))
	_add_wall(Vector2(board_w + _WALL * 0.5, mid_y), Vector2(_WALL, tall))

func _add_wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	wall.add_child(shape)
	add_child(wall)
