@tool
class_name ScrapHeap
extends Structure
## A salvageable pile. While the player is in range it highlights like any [Structure];
## each interact ejects one item from its [LootTable] onto the ground as a physical pickup,
## and spends one of its limited salvages. The player collects the scrap through the normal
## item-collection flow — the heap never touches the player or the inventory. When it runs
## out it collapses: the model shrinks to a flat pile and the heap goes inert.

#region Constants

const SCENE_PATH := "res://entities/structures/scrap_heap/scrap_heap.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

## Duration of the collapse shrink. Matches the project's default animation duration.
const COLLAPSE_DURATION: float = 0.35

## A salvaged item pops off the top of the pile in a small random-direction arc and lands on
## the ground around the base. Spawn sits ABOVE the pile's collider top (~1.4) plus the item's
## own half-height, so items start clear of the pile instead of inside it (spawning inside makes
## physics shove them out, flattening the arc and scraping the model). The outward toss then
## carries them past the footprint. Tuned for a small geyser, not a launch.
const _EJECT_SPAWN_HEIGHT: float = 1.9
const _EJECT_UP_MIN: float = 2.8
const _EJECT_UP_MAX: float = 3.4
const _EJECT_OUT_MIN: float = 4.8
const _EJECT_OUT_MAX: float = 5.8
const _EJECT_SPIN: float = 0.4

#endregion

#region Signals

## Emitted on a successful salvage, carrying the item blueprint that was ejected.
signal salvaged(item_blueprint: ItemBlueprint)
## Emitted once when the heap runs out of salvages and collapses.
signal collapsed

#endregion

#region Properties

@export var blueprint: ScrapHeapBlueprint

@export var max_interactions: int = 3
@export var loot_table: LootTable
@export var collapse_scale: Vector3 = Vector3(0.7, 0.05, 0.7)

## Times this heap has been salvaged so far. Collapses once it reaches [member max_interactions].
var interactions: int = 0

var _collapsed: bool = false

#endregion

#region Lifecycle

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	if blueprint != null:
		apply_blueprint(blueprint)

func interact(_player: Player) -> void:
	if Engine.is_editor_hint() or _collapsed:
		return

	var drop: ItemBlueprint = loot_table.roll() if loot_table != null else null
	if drop == null:
		return

	var item: Item = _eject(drop)
	# Modules only ever leave a heap damaged — working ones come from fabrication or refurbishment.
	if item != null and drop.category == Item.Category.MODULE:
		item.add_tag(Item.Tag.DAMAGED)

	interactions += 1
	salvaged.emit(drop)
	interacted.emit()

	if interactions >= max_interactions:
		_collapse()

#endregion

#region Salvaging

# Spawns the rolled item as a physical pickup popping out of the pile in a random direction,
# returning it so the caller can stamp tags. The player collects it through the normal
# item-collection flow; the heap is done with it.
func _eject(item_blueprint: ItemBlueprint) -> Item:
	var item: Item = Item.create(item_blueprint)
	if item == null:
		return null
	get_parent().add_child(item)

	# Random azimuth, mostly-up with a small outward lean: a little geyser pop, not a rocket.
	var angle: float = randf() * TAU
	var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
	item.global_position = global_position + Vector3.UP * _EJECT_SPAWN_HEIGHT + out * 0.2

	var impulse: Vector3 = out * randf_range(_EJECT_OUT_MIN, _EJECT_OUT_MAX) + Vector3.UP * randf_range(_EJECT_UP_MIN, _EJECT_UP_MAX)
	# A little tumble so the spray reads as debris rather than a placed object.
	var spin: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _EJECT_SPIN
	# launch() (not a bare impulse) keeps the item non-collectable until it lands, so mashing
	# interact ejects a stream instead of grabbing each piece mid-air.
	item.launch(impulse, spin)
	return item

#endregion

#region Collapse

func _collapse() -> void:
	if _collapsed:
		return
	_collapsed = true

	# Go inert: clear the outline and stop detecting players. The zone is the authority on
	# who's inside, so drop out of every in-range player's structure list before we stop.
	interact_zone.should_highlight = false
	interact_zone.clear_highlight()
	for body: Node3D in interact_zone.get_overlapping_bodies():
		var player: Player = body as Player
		if player != null:
			player.remove_structure_in_range(self)
	interact_zone.set_deferred("monitoring", false)

	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(model, "scale", collapse_scale, COLLAPSE_DURATION)
	tween.tween_callback(_settle)

# The flattened remains shouldn't block the player or block line of sight to interactables.
func _settle() -> void:
	collision_shape.disabled = true
	collapsed.emit()

#endregion

#region Blueprinting

func apply_blueprint(_blueprint: ScrapHeapBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return

	blueprint = _blueprint
	max_interactions = _blueprint.max_interactions
	loot_table = _blueprint.loot_table
	collapse_scale = _blueprint.collapse_scale

static func create(_blueprint: ScrapHeapBlueprint) -> ScrapHeap:
	if not _blueprint:
		Log.error("Blueprint required to create ScrapHeap")
		return null

	var heap: ScrapHeap = SCENE.instantiate()
	heap.apply_blueprint(_blueprint)
	return heap

#endregion
