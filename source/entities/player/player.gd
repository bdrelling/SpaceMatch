class_name Player
extends CharacterBody3D

const SCENE_PATH := "res://entities/player/player.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## How directional input maps to movement and facing. Toggled to match the
## camera mode (see [Overworld]): a free camera wants [code]DIRECTIONAL[/code], a
## follow-behind camera wants [code]STRAFE[/code].
enum MovementScheme {
	## Camera-relative: the body turns to face wherever you push (Mario/Zelda).
	## Pressing back makes the body about-face and run toward the camera.
	DIRECTIONAL,
	## The body faces camera-forward at all times; input forward/back/strafes
	## without turning. Pressing back back-pedals. You turn by orbiting the camera.
	STRAFE,
}

## How a gamepad sprint press behaves ([member GameSettings.sprint_mode]). Keyboard
## sprint is always hold-to-sprint; only gamepad presses consult this.
enum SprintMode {
	## A press latches sprint on until the player stops, runs dry, or presses again.
	TOGGLE,
	## Sprint only while the button is held.
	HOLD,
}

## Fraction of max stamina below which the bar reads red and sprinting can no
## longer be *initiated*. An in-progress sprint may keep draining past this point
## down to zero, but once stamina drops here the player must recover back above
## it before they can start sprinting again (hysteresis prevents on/off stutter).
const STAMINA_RED_THRESHOLD: float = 0.1

## Minimum seconds between item collections, however the presses arrive — a held button
## repeats on this interval, and mashing the button can't beat it (items only — a held
## button never triggers a [Structure], see [method _update_held_collect]).
const COLLECT_REPEAT_INTERVAL: float = 0.25

#region Stat bounds
## Min/max/step/default for each tunable stat — the single source of truth shared
## by the PlayerBlueprint @export_range hints + defaults, this node's runtime fields,
## and the debug menu's drag controls. Each value lives here exactly once; the node
## vars and PlayerBlueprint reference these, never a re-typed literal.

const MOVE_SPEED_MIN: float = 0.1
const MOVE_SPEED_MAX: float = 50.0
const MOVE_SPEED_STEP: float = 0.05
const MOVE_SPEED_DEFAULT: float = 4.5

const JUMP_VELOCITY_MIN: float = 0.0
const JUMP_VELOCITY_MAX: float = 30.0
const JUMP_VELOCITY_STEP: float = 0.1
const JUMP_VELOCITY_DEFAULT: float = 9.0

const SPRINT_MULTIPLIER_MIN: float = 0.5
const SPRINT_MULTIPLIER_MAX: float = 10.0
const SPRINT_MULTIPLIER_STEP: float = 0.05
const SPRINT_MULTIPLIER_DEFAULT: float = 2.4

const GROUND_DECELERATION_MIN: float = 0.0
const GROUND_DECELERATION_MAX: float = 200.0
const GROUND_DECELERATION_STEP: float = 0.5
const GROUND_DECELERATION_DEFAULT: float = 25.0

const PIVOT_SPEED_MIN: float = 0.0
const PIVOT_SPEED_MAX: float = 50.0
const PIVOT_SPEED_STEP: float = 0.1
const PIVOT_SPEED_DEFAULT: float = 10.0

const CAPSULE_RADIUS_MIN: float = 0.1
const CAPSULE_RADIUS_MAX: float = 2.0
const CAPSULE_RADIUS_STEP: float = 0.01
const CAPSULE_RADIUS_DEFAULT: float = 0.4

const CAPSULE_HEIGHT_MIN: float = 0.5
const CAPSULE_HEIGHT_MAX: float = 5.0
const CAPSULE_HEIGHT_STEP: float = 0.01
const CAPSULE_HEIGHT_DEFAULT: float = 1.6

const MAX_STAMINA_MIN: float = 1.0
const MAX_STAMINA_MAX: float = 1000.0
const MAX_STAMINA_STEP: float = 0.5
const MAX_STAMINA_DEFAULT: float = 1000.0

const STAMINA_DRAIN_RATE_MIN: float = 0.0
const STAMINA_DRAIN_RATE_MAX: float = 100.0
const STAMINA_DRAIN_RATE_STEP: float = 0.1
const STAMINA_DRAIN_RATE_DEFAULT: float = 15.0

const STAMINA_REGEN_RATE_MIN: float = 0.0
const STAMINA_REGEN_RATE_MAX: float = 100.0
const STAMINA_REGEN_RATE_STEP: float = 0.1
const STAMINA_REGEN_RATE_DEFAULT: float = 8.0
#endregion

@export var blueprint: PlayerBlueprint

signal stamina_changed(current: float, maximum: float)

## Emitted after the player interacts with a [Structure] (post [method Structure.interact]). UI that
## reacts to structures (e.g. [CraftingStationUI]) listens here rather than the structure reaching
## out to a panel — structures stay unaware of the overlay layer (Observer; see signals.md).
signal structure_interacted(structure: Structure)
## Emitted when a [Structure] leaves the player's interaction range.
signal structure_exited(structure: Structure)

@onready var dust_emitter: DustEmitter = %DustEmitter
@onready var _visuals: Node3D = %Visuals
@onready var _model_root: Node3D = %Model
@onready var _collision_shape: CollisionShape3D = %CollisionShape3D
@onready var rustboard: Rustboard = %Rustboard
@onready var inventory: Inventory = %Inventory
@onready var item_collector: ItemCollector = %ItemCollector

## The camera this player moves relative to. Wire it in the scene (inspector);
## the player reads its orientation and follows its [signal PlayerCamera.mode_changed].
@export var player_camera: PlayerCamera

var rustboarding: bool = false
## Derived from the camera mode (see [method _sync_movement_scheme]) and read by
## [PlayerMovementState]. Not set by hand — it follows [member player_camera].
var movement_scheme: MovementScheme = MovementScheme.DIRECTIONAL
var stamina: float = MAX_STAMINA_DEFAULT
var _sprinting: bool = false
## Set by a gamepad sprint press in [constant SprintMode.TOGGLE]; cleared when the
## sprint ends on its own (see [method _update_sprinting]).
var _sprint_latched: bool = false
## Armed by an interact press; while it stays armed (button held), the hold-to-collect
## repeat runs (see [method _update_held_collect]).
var _collect_held: bool = false
var _collect_repeat_timer: float = 0.0
var _animation_player: AnimationPlayer

@export_range(MOVE_SPEED_MIN, MOVE_SPEED_MAX, MOVE_SPEED_STEP)
var move_speed: float = MOVE_SPEED_DEFAULT
@export_range(JUMP_VELOCITY_MIN, JUMP_VELOCITY_MAX, JUMP_VELOCITY_STEP)
var jump_velocity: float = JUMP_VELOCITY_DEFAULT
@export_range(SPRINT_MULTIPLIER_MIN, SPRINT_MULTIPLIER_MAX, SPRINT_MULTIPLIER_STEP)
var sprint_multiplier: float = SPRINT_MULTIPLIER_DEFAULT
@export_range(GROUND_DECELERATION_MIN, GROUND_DECELERATION_MAX, GROUND_DECELERATION_STEP)
var ground_deceleration: float = GROUND_DECELERATION_DEFAULT
@export_range(PIVOT_SPEED_MIN, PIVOT_SPEED_MAX, PIVOT_SPEED_STEP)
var pivot_speed: float = PIVOT_SPEED_DEFAULT

@export_group("Stamina")
@export_range(MAX_STAMINA_MIN, MAX_STAMINA_MAX, MAX_STAMINA_STEP)
var max_stamina: float = MAX_STAMINA_DEFAULT
@export_range(STAMINA_DRAIN_RATE_MIN, STAMINA_DRAIN_RATE_MAX, STAMINA_DRAIN_RATE_STEP)
var stamina_drain_rate: float = STAMINA_DRAIN_RATE_DEFAULT
@export_range(STAMINA_REGEN_RATE_MIN, STAMINA_REGEN_RATE_MAX, STAMINA_REGEN_RATE_STEP)
var stamina_regen_rate: float = STAMINA_REGEN_RATE_DEFAULT

var _structures_in_range: Array[Structure] = []

func _unhandled_input(event: InputEvent) -> void:
	# Only a gamepad press can latch sprint — keyboard sprint stays hold-to-sprint
	# regardless of the setting, so the latch never surprises a keyboard player.
	if ManagedInput.event_is_action_pressed(event, InputAction.SPRINT) and event is InputEventJoypadButton:
		if Settings.game.sprint_mode == SprintMode.TOGGLE:
			_sprint_latched = not _sprint_latched
	if ManagedInput.event_is_action_pressed(event, InputAction.INTERACT):
		# Interact targets whatever's highlighted: in exclusive mode that's the single focus, so
		# "what's lit up is what you act on". In shared mode, fall back to nearest — item first.
		if InteractionFocus.exclusive:
			_interact_with_focus()
		elif not _try_collect_nearest_item():
			_interact_with_nearest_structure()
		# Holding the button past the press keeps collecting items on an interval.
		_collect_held = true

## Acts on the focused interactable — collects it if it's an [Item], interacts if it's a
## [Structure]. Falls back to nearest when nothing is focused (e.g. a non-highlighting zone).
func _interact_with_focus() -> void:
	var source: Object = InteractionFocus.focused_source()
	var item: Item = source as Item
	if item != null:
		_collect_item(item)
		return
	var structure: Structure = source as Structure
	if structure != null:
		_interact_with_structure(structure)
		return
	if not _try_collect_nearest_item():
		_interact_with_nearest_structure()

## Picks up the closest in-range item if it has a blueprint and fits in the inventory.
## Returns true when the press was consumed by an item (collected now, or deferred by the
## rate limit) so it never falls through to a [Structure] behind it.
func _try_collect_nearest_item() -> bool:
	return _collect_item(item_collector.get_nearest())

## Collects [param item] if it has a blueprint and fits in the inventory. Returns true on
## success, and also while [constant COLLECT_REPEAT_INTERVAL] hasn't elapsed since the last
## collect — the press is consumed and the held repeat grabs the item once the timer runs out.
func _collect_item(item: Item) -> bool:
	if item == null or item.blueprint == null:
		return false
	if _collect_repeat_timer > 0.0:
		return true
	if not inventory.add(item):
		return false
	_collect_repeat_timer = COLLECT_REPEAT_INTERVAL
	item_collector.forget(item)
	item.collect_into(self)
	return true

## Ejects one item of [param stack]'s variant from the inventory into the world — the reverse
## of a collect. Spawns the item just in front of the player and tosses it out so it falls to
## the ground (it lands on its [constant CollisionLayer.PROPS] layer, ready to be picked back
## up). No-op when the inventory doesn't hold the variant.
func drop_item(stack: ItemStack) -> void:
	if stack == null or stack.item_blueprint == null:
		return
	if not inventory.remove_from_stack(stack, 1):
		return

	var item: Item = stack.create_item()
	if item == null:
		return
	get_parent().add_child(item)

	var forward: Vector3 = -global_transform.basis.z
	item.global_position = global_position + forward * 0.6 + Vector3.UP * 1.0
	# launch() holds it non-collectable until it lands, so a drop isn't instantly re-collected.
	item.launch(forward * 2.0 + Vector3.UP * 2.0)

func add_structure_in_range(structure: Structure) -> void:
	if not _structures_in_range.has(structure):
		_structures_in_range.append(structure)

func remove_structure_in_range(structure: Structure) -> void:
	_structures_in_range.erase(structure)
	structure_exited.emit(structure)

func _interact_with_nearest_structure() -> void:
	var nearest: Structure = null
	var nearest_distance_squared: float = INF
	for structure: Structure in _structures_in_range:
		if not is_instance_valid(structure):
			continue
		var distance_squared: float = global_position.distance_squared_to(structure.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = structure
			nearest_distance_squared = distance_squared
	if nearest != null:
		_interact_with_structure(nearest)

## Runs a structure's interaction and announces it, so structure-reactive UI can respond without the
## structure knowing the UI exists (see [signal structure_interacted]).
func _interact_with_structure(structure: Structure) -> void:
	structure.interact(self)
	structure_interacted.emit(structure)

## Hold-to-collect: while the interact button stays held after a press, collects the highlighted
## item every [constant COLLECT_REPEAT_INTERVAL]. Items only — a held button never triggers a
## [Structure], so vacuuming up a pile of items can't accidentally re-open the structure behind it.
func _update_held_collect() -> void:
	if not ManagedInput.is_action_pressed(InputAction.INTERACT):
		_collect_held = false
	if not _collect_held or _collect_repeat_timer > 0.0:
		return
	if InteractionFocus.exclusive:
		var source: Object = InteractionFocus.focused_source()
		if source != null:
			# A focused structure swallows the repeat — never reach past the highlight to an item.
			_collect_item(source as Item)
			return
	_try_collect_nearest_item()

## Ticks the collect rate limit and the hold-to-collect repeat.
func _update_collect(delta: float) -> void:
	_collect_repeat_timer = maxf(_collect_repeat_timer - delta, 0.0)
	_update_held_collect()

func _physics_process(delta: float) -> void:
	_update_sprinting()
	_update_collect(delta)
	if _sprinting:
		stamina = maxf(stamina - stamina_drain_rate * delta, 0.0)
	else:
		stamina = minf(stamina + stamina_regen_rate * delta, max_stamina)
	stamina_changed.emit(stamina, max_stamina)
	_update_visual_tilt(delta)

## Riding speed at which the carve lean reaches its full angle.
const LEAN_FULL_SPEED: float = 10.0

## While rustboarding, leans [member _visuals] (model + board) to match the floor;
## otherwise eases it back upright. The body itself stays Y-up — tilting the
## capsule would break floor detection — so the lean is visual-only. Airborne
## righting runs at the board's slower [member Rustboard.air_righting_speed] so a
## launch carries its lean into the air.
func _update_visual_tilt(delta: float) -> void:
	var target := Quaternion.IDENTITY
	var speed: float = rustboard.alignment_speed
	if rustboarding:
		if is_on_floor():
			var local_normal: Vector3 = global_basis.inverse() * get_floor_normal()
			target = RustboardPhysics.tilt_for_normal(local_normal)
		else:
			speed = rustboard.air_righting_speed
		target *= _carve_lean()
	var blend: float = clampf(speed * delta, 0.0, 1.0)
	_visuals.quaternion = _visuals.quaternion.slerp(target, blend)

## Banks board and rider into the turn — full angle at full steer once up to
## [constant LEAN_FULL_SPEED]. Positive steer turns right, so positive roll
## around the board's forward axis dips the right edge into the carve.
func _carve_lean() -> Quaternion:
	if rustboard.lean_degrees <= 0.0:
		return Quaternion.IDENTITY
	var horizontal_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	var speed_factor: float = clampf(horizontal_speed / LEAN_FULL_SPEED, 0.0, 1.0)
	var lean: float = deg_to_rad(rustboard.lean_degrees) * rustboard.steer_value * speed_factor
	return Quaternion(Vector3.FORWARD, lean)

func is_sprinting() -> bool:
	return _sprinting

func _update_sprinting() -> void:
	var move_input: Vector2 = Vector2(
		ManagedInput.get_axis(InputAction.STRAFE_LEFT, InputAction.STRAFE_RIGHT),
		ManagedInput.get_axis(InputAction.MOVE_BACKWARD, InputAction.MOVE_FORWARD),
	)
	var is_moving: bool = move_input.length() > 0.1
	# A latched sprint that ends on its own — standing still or running dry — drops
	# the latch rather than resuming by surprise later. Air time keeps it, so a
	# sprint-jump is still a sprint on landing.
	if _sprint_latched and _sprinting and (not is_moving or stamina <= 0.0):
		_sprint_latched = false
	var wants_sprint: bool = (_sprint_latched or ManagedInput.is_action_pressed(InputAction.SPRINT)) and is_moving and is_on_floor()
	if not wants_sprint:
		_sprinting = false
	elif _sprinting:
		_sprinting = stamina > 0.0
	else:
		_sprinting = stamina > max_stamina * STAMINA_RED_THRESHOLD

func _ready() -> void:
	add_to_group(&"player")
	apply_blueprint(blueprint)
	_apply_visual_layer(DustEmitter.PLAYER_VISUAL_LAYER)
	dust_emitter.setup_ground_sampler()
	_connect_camera()

func _apply_visual_layer(layer: int) -> void:
	for child: Node in get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers |= layer
		_apply_visual_layer_recursive(child, layer)

func _apply_visual_layer_recursive(node: Node, layer: int) -> void:
	for child: Node in node.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers |= layer
		_apply_visual_layer_recursive(child, layer)

func snap_camera() -> void:
	if is_instance_valid(player_camera):
		player_camera.snap()

func get_camera_yaw_basis() -> Basis:
	if is_instance_valid(player_camera):
		return player_camera.get_yaw_basis()
	return Basis.IDENTITY

func get_facing_yaw() -> float:
	return rotation.y

func get_camera_facing_yaw() -> float:
	if is_instance_valid(player_camera):
		return player_camera.get_facing_yaw()
	return rotation.y

#region Camera coupling

func _connect_camera() -> void:
	if not is_instance_valid(player_camera):
		return
	player_camera.mode_changed.connect(_on_camera_mode_changed)
	_sync_movement_scheme(player_camera.mode)

func _on_camera_mode_changed(camera_mode: PlayerCamera.Mode) -> void:
	_sync_movement_scheme(camera_mode)

## A follow-behind camera ([constant PlayerCamera.Mode.CHASE] and its racing
## variant [constant PlayerCamera.Mode.DOWNHILL_CHASE]) strafes; every other
## (free) camera moves camera-relative.
func _sync_movement_scheme(camera_mode: PlayerCamera.Mode) -> void:
	movement_scheme = (
		MovementScheme.STRAFE
		if camera_mode == PlayerCamera.Mode.CHASE or camera_mode == PlayerCamera.Mode.DOWNHILL_CHASE
		else MovementScheme.DIRECTIONAL
	)

#endregion

func pivot_toward(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var target_angle: float = atan2(-direction.x, -direction.z)
	var blend: float = clampf(pivot_speed * delta, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_angle, blend)

func play_animation(animation_name: StringName, transition: float = 0.2) -> void:
	if _animation_player != null and _animation_player.has_animation(animation_name):
		_animation_player.play(animation_name, transition)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

#region Blueprinting

# Applies the tunable stats (movement + collision) without touching the model.
# Cheap enough to call live every frame while a value is being dragged.
func apply_stats(_blueprint: PlayerBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply stats; blueprint not found")
		return
	move_speed = _blueprint.move_speed
	jump_velocity = _blueprint.jump_velocity
	sprint_multiplier = _blueprint.sprint_multiplier
	ground_deceleration = _blueprint.ground_deceleration
	max_stamina = _blueprint.max_stamina
	stamina_drain_rate = _blueprint.stamina_drain_rate
	stamina_regen_rate = _blueprint.stamina_regen_rate
	pivot_speed = _blueprint.pivot_speed
	stamina = minf(stamina, max_stamina)
	if not is_node_ready():
		return
	var capsule: CapsuleShape3D = _collision_shape.shape as CapsuleShape3D
	if capsule:
		capsule.radius = _blueprint.capsule_radius
		capsule.height = _blueprint.capsule_height
		_collision_shape.position.y = _blueprint.capsule_height / 2.0

func apply_blueprint(_blueprint: PlayerBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return
	blueprint = _blueprint
	apply_stats(_blueprint)
	stamina = max_stamina
	if not is_node_ready():
		return
	for child: Node in _model_root.get_children():
		child.queue_free()
	if _blueprint.model_scene:
		var instance: Node3D = _blueprint.model_scene.instantiate() as Node3D
		_model_root.add_child(instance)
		_animation_player = _find_animation_player(instance)
		# Keep highlighted structures' x-ray fill from drawing over the player when it stands
		# in front of one (the player marks itself out of every silhouette highlight).
		SilhouetteHighlighter.set_excluded(instance, true)

static func create(_blueprint: PlayerBlueprint) -> Player:
	if not _blueprint:
		Log.error("Blueprint required to create Player")
		return null
	var player: Player = SCENE.instantiate()
	player.apply_blueprint(_blueprint)
	return player

#endregion
