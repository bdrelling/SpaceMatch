@tool
class_name CraftingStation
extends Structure
## Base for crafting stations. While the player is in range it
## highlights like any [Structure]; interacting surfaces a panel listing the station's recipes.
## Picking one queues a craft: the station works through its queue one craft at a time, each
## taking [member Recipe.duration] seconds — inputs are consumed from the player's inventory when
## a craft begins, and its outputs eject as physical pickups when it completes, collected through
## the normal item flow — the station never adds to the inventory. The recipes live in a
## [RecipeBook], built from the assigned [RecipeBookBlueprint].
##
## The station owns no UI and never looks one up: the player emits [signal Player.structure_interacted]
## and a [CraftingStationUI] opens the right panel (Observer — see armory/docs/godot/patterns/signals.md).
## Stations stay unaware of the overlay layer. A station that needs a bespoke panel points
## [member panel_scene] at a different scene; one that needs bespoke logic overrides [method craft].

#region Constants

const _EJECT_SPAWN_HEIGHT: float = 1.4
const _EJECT_UP: float = 3.0
const _EJECT_OUT: float = 3.5
const _EJECT_SPIN: float = 0.4

const _DEFAULT_PANEL: PackedScene = preload("res://systems/crafting/ui/crafting_panel/crafting_panel.tscn")

#endregion

#region Signals

## Emitted when the station starts working after being idle.
signal work_started

## Emitted when the queue drains and the station falls idle.
signal work_finished

## Emitted when a queued craft begins, right after its inputs are consumed.
signal craft_started(recipe: Recipe)

## Emitted as the active craft runs, with [param progress] in 0..1.
signal craft_progressed(recipe: Recipe, progress: float)

## Emitted on a successful craft, carrying the recipe that ran.
signal crafted(recipe: Recipe)

#endregion

#region Properties

## Links this station to its saved [CraftingStationState] — the 3D station and its arcade stage share
## one state by matching ids. Empty when the station persists nothing.
@export var id: StringName = &""

@export var recipe_book_blueprint: RecipeBookBlueprint

## Panel shown when the player interacts. Defaults to the shared [CraftingPanel]; point it at a
## different scene (whose root extends [CraftingPanel]) for a bespoke UI — the [CraftingStationUI]
## instances whatever is named here.
@export var panel_scene: PackedScene = _DEFAULT_PANEL

## Title shown on the panel (e.g. "Recycle"). Falls back to the node name when left empty.
@export var action_label: String

## Whether the panel offers craft-all buttons — one per recipe plus one for the whole book
## (see [method craft_all]).
@export var allows_craft_all: bool = false

## Flag that completes crafts immediately when enabled (see [FeatureFlagger]).
@export var instant_craft_flag: FeatureFlag = preload("res://resources/feature_flags/instant_crafting.tres")

## Built from [member recipe_book_blueprint] on ready (see [RecipeBook]).
var recipe_book: RecipeBook

## True while the station has a craft running or queued.
var is_working: bool:
	get:
		return _working

var _queue: Array[CraftOrder] = []
var _active_recipe: Recipe
var _active_products: Array[ItemStack] = []
var _elapsed: float = 0.0
var _working: bool = false

#endregion

#region Lifecycle

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	if recipe_book_blueprint != null:
		recipe_book = RecipeBook.create(recipe_book_blueprint)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_advance(delta)

#endregion

#region Crafting

## Queues one craft of [param recipe], paid from [param inventory]. No-op (returns false) when
## the inventory can't cover the inputs. Override for bespoke crafting behaviour.
func craft(inventory: Inventory, recipe: Recipe) -> bool:
	if inventory == null or recipe == null:
		return false
	if not recipe.can_craft(inventory):
		return false
	_enqueue(CraftOrder.new(inventory, recipe, false))
	return true

## Queues crafting [param recipe] — or, when null, whichever book recipe [param inventory] can
## afford — over and over until the inventory can no longer cover one. No-op (returns false)
## when nothing is craftable right now.
func craft_all(inventory: Inventory, recipe: Recipe = null) -> bool:
	if inventory == null:
		return false
	var order := CraftOrder.new(inventory, recipe, true)
	if _resolve_recipe(order) == null:
		return false
	_enqueue(order)
	return true

func _enqueue(order: CraftOrder) -> void:
	_queue.append(order)
	if not _working:
		_working = true
		_elapsed = 0.0
		work_started.emit()
	_advance(0.0)

# Drives the active craft forward by [param delta] seconds. Leftover time carries into the next
# craft, so zero-duration crafts (the instant flag) chain until the queue drains in one call.
func _advance(delta: float) -> void:
	if not _working:
		return
	if _active_recipe == null and not _begin_next_craft():
		return
	_elapsed += delta
	while _active_recipe != null and _elapsed >= _craft_duration(_active_recipe):
		_elapsed -= _craft_duration(_active_recipe)
		_complete_craft()
		if not _begin_next_craft():
			return
	if _active_recipe != null:
		craft_progressed.emit(_active_recipe, clampf(_elapsed / _craft_duration(_active_recipe), 0.0, 1.0))

# Starts the queue's next affordable craft, consuming its inputs and rolling its products up
# front (so a weighted recipe's checked roll is the one that ejects). Repeating orders stay
# queued and re-resolve each craft; orders that can't pay or would yield nothing are dropped.
# Returns false (finishing the work) when the queue empties.
func _begin_next_craft() -> bool:
	while not _queue.is_empty():
		var order: CraftOrder = _queue.front()
		var recipe: Recipe = _resolve_recipe(order)
		var products: Array[ItemStack] = []
		if recipe != null:
			products = recipe.produce()
		if recipe == null or products.is_empty():
			_queue.pop_front()
			continue
		if not order.repeating:
			_queue.pop_front()
		_consume_inputs(order.inventory, recipe)
		_active_recipe = recipe
		_active_products = products
		craft_started.emit(recipe)
		return true
	_finish_work()
	return false

# Ejects the active craft's products and announces it. Inputs were already consumed at begin.
func _complete_craft() -> void:
	var recipe := _active_recipe
	var products := _active_products
	_active_recipe = null
	_active_products = []
	for product: ItemStack in products:
		if product == null or product.item_blueprint == null:
			continue
		for index in product.quantity:
			_eject(product)
	crafted.emit(recipe)

# The recipe [param order] runs next: its own when still affordable, otherwise the book's first
# affordable recipe for whole-book orders. Null when nothing can be paid for.
func _resolve_recipe(order: CraftOrder) -> Recipe:
	if order.inventory == null:
		return null
	if order.recipe != null:
		return order.recipe if order.recipe.can_craft(order.inventory) else null
	if recipe_book == null:
		return null
	for recipe: Recipe in recipe_book.all_recipes():
		if recipe != null and recipe.can_craft(order.inventory):
			return recipe
	return null

func _consume_inputs(inventory: Inventory, recipe: Recipe) -> void:
	for ingredient: ItemStack in recipe.inputs:
		if ingredient == null or ingredient.item_blueprint == null:
			continue
		inventory.remove(ingredient.item_blueprint.id, ingredient.quantity, ingredient.tags)

# Honors the instant-craft flag; never negative.
func _craft_duration(recipe: Recipe) -> float:
	if instant_craft_flag != null and FeatureFlagger.is_enabled(instant_craft_flag):
		return 0.0
	return maxf(recipe.duration, 0.0)

func _finish_work() -> void:
	if not _working:
		return
	_working = false
	_elapsed = 0.0
	work_finished.emit()

# Spawns one produced item of the product stack's variant just above and in front of the station
# and tosses it onto the ground. launch() (not a bare impulse) keeps it non-collectable until it
# lands.
func _eject(product: ItemStack) -> void:
	var item: Item = product.create_item()
	if item == null:
		return
	get_parent().add_child(item)

	var out: Vector3 = -global_transform.basis.z.normalized()
	item.global_position = global_position + Vector3.UP * _EJECT_SPAWN_HEIGHT + out * 0.5

	var impulse: Vector3 = out * _EJECT_OUT + Vector3.UP * _EJECT_UP
	var spin: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _EJECT_SPIN
	item.launch(impulse, spin)

#endregion

#region Classes

## One queued run of a recipe, paid from [member inventory]. A [member repeating] order re-arms
## after every completed craft — with a null [member recipe] it sweeps the whole book — until
## nothing affordable remains.
class CraftOrder:
	var inventory: Inventory
	var recipe: Recipe
	var repeating: bool

	func _init(_inventory: Inventory, _recipe: Recipe, _repeating: bool) -> void:
		inventory = _inventory
		recipe = _recipe
		repeating = _repeating

#endregion
