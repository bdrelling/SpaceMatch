class_name Inventory
extends Node
## Holds [ItemStack]s keyed by item variant (id + tags), constrained by an optional
## [CapacityRule]. A variant spans multiple stacks when its blueprint caps stack size.
## Grid-ruled inventories also track a [StackPlacement] per stack.
##
## Stacks and placements live on an [InventoryState] (its runtime, save-able data); the node owns
## one by default and operates on it in place. [method bind] swaps in an external state — e.g. a
## [PlayerState]'s — so the node and the owning state share one source of truth.

#region Constants

const SCENE_PATH := "res://systems/inventory/inventory/inventory.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

#endregion

#region Signals

signal changed(inventory: Inventory)

#endregion

#region Properties

## What this inventory may hold. Null means unconstrained.
@export var capacity_rule: CapacityRule

## Authored configuration, applied on ready when set. Leave null to configure
## [member capacity_rule] directly instead.
@export var blueprint: InventoryBlueprint

## Runtime data — the stacks (+ grid placements). Owns one by default so an unbound inventory
## works standalone; [method bind] swaps in an external [InventoryState] to share data with its owner.
var _state: InventoryState = InventoryState.new()

## Number of stacks currently held.
var size: int:
	get:
		return _state.stacks.size()

#endregion

func _ready() -> void:
	if blueprint != null:
		apply_blueprint(blueprint)

#region Methods

## Adds [param amount] of [param item]'s variant: existing stacks are topped up to the
## blueprint's [member ItemBlueprint.max_stack_size], then new stacks open for the rest.
## All or nothing — returns false when the item is invalid or the whole amount doesn't fit.
func add(item: Item, amount: int = 1) -> bool:
	if item == null or item.blueprint == null:
		Log.error("Unable to add to inventory; item not found")
		return false
	return add_variant(item.blueprint, item.tags, amount)

## Adds [param amount] of the variant described by [param item_blueprint] + [param tags],
## without needing a world [Item]. Same distribution and all-or-nothing rules as [method add].
func add_variant(item_blueprint: ItemBlueprint, tags: Array[Item.Tag], amount: int = 1) -> bool:
	if item_blueprint == null:
		Log.error("Unable to add to inventory; item blueprint not found")
		return false

	if amount <= 0:
		return false

	var variant_id := ItemVariantId.new(item_blueprint.id, tags)
	var max_stack_size: int = item_blueprint.max_stack_size

	# Distribute the amount: top up existing stacks of the variant, then open new stacks.
	var merge_stacks: Array[ItemStack] = []
	var merge_amounts: Array[int] = []
	var remaining := amount
	for stack: ItemStack in _state.stacks:
		if remaining <= 0:
			break
		if not _matches(stack, variant_id):
			continue
		var room := remaining if max_stack_size <= 0 else mini(remaining, maxi(max_stack_size - stack.quantity, 0))
		if room > 0:
			merge_stacks.append(stack)
			merge_amounts.append(room)
			remaining -= room
	var new_stack_quantities: Array[int] = []
	while remaining > 0:
		var portion := remaining if max_stack_size <= 0 else mini(remaining, max_stack_size)
		new_stack_quantities.append(portion)
		remaining -= portion

	# Capacity check; a grid additionally needs a placement for every new stack.
	if capacity_rule != null and not capacity_rule.can_add(_state, item_blueprint, amount, new_stack_quantities.size()):
		return false
	var grid_rule := capacity_rule as GridCapacityRule
	var new_placements: Array[StackPlacement] = []
	if grid_rule != null and not new_stack_quantities.is_empty():
		new_placements = grid_rule.find_placements(_state, item_blueprint, new_stack_quantities.size())
		if new_placements.is_empty():
			return false

	for index in merge_stacks.size():
		merge_stacks[index].add(merge_amounts[index])
	for index in new_stack_quantities.size():
		_state.stacks.append(ItemStack.create(item_blueprint, new_stack_quantities[index], tags))
		if grid_rule != null:
			_state.placements.append(new_placements[index])

	Log.info("Added %d %s to %s inventory" % [amount, Item.tagged_name(item_blueprint.name, tags), _owner_label()])
	changed.emit(self)
	return true

## Removes up to [param amount] of the variant, draining the newest stacks first.
func remove(item_id: int, amount: int = 1, tags: Array[Item.Tag] = []) -> void:
	var variant_id := ItemVariantId.new(item_id, tags)
	var remaining := amount
	var removed := 0
	var removed_name := ""
	for index in range(_state.stacks.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var stack: ItemStack = _state.stacks[index]
		if not _matches(stack, variant_id):
			continue
		removed_name = stack.display_name
		var taken := mini(remaining, stack.quantity)
		stack.remove(taken)
		remaining -= taken
		removed += taken
		if stack.quantity <= 0:
			_state.stacks.remove_at(index)
			if index < _state.placements.size():
				_state.placements.remove_at(index)

	if removed == 0:
		return

	Log.info("Removed %d %s from %s inventory" % [removed, removed_name, _owner_label()])
	changed.emit(self)

## Removes up to [param amount] from [param stack] itself — the addressed stack, not just
## any stack of its variant — erasing it (and its grid placement) when emptied. Returns
## false when the stack isn't in this inventory.
func remove_from_stack(stack: ItemStack, amount: int = 1) -> bool:
	var index := _state.stacks.find(stack)
	if index == -1 or amount <= 0:
		return false
	var taken := mini(amount, stack.quantity)
	stack.remove(taken)
	if stack.quantity <= 0:
		_state.stacks.remove_at(index)
		if index < _state.placements.size():
			_state.placements.remove_at(index)
	Log.info("Removed %d %s from %s inventory" % [taken, stack.display_name, _owner_label()])
	changed.emit(self)
	return true

## Moves [param amount] of [param stack] (the whole stack when negative) into [param target],
## all or nothing against the target's capacity rule. The stack's grid placement never
## transfers — the target re-places per its own rule. Returns false when the stack isn't in
## this inventory or the target can't take the whole amount.
func transfer_to(target: Inventory, stack: ItemStack, amount: int = -1) -> bool:
	if target == null or target == self or stack == null or stack.item_blueprint == null:
		return false
	if not _state.stacks.has(stack):
		return false
	var moved := stack.quantity if amount < 0 else mini(amount, stack.quantity)
	if moved <= 0:
		return false
	if not target.add_variant(stack.item_blueprint, stack.tags, moved):
		return false
	return remove_from_stack(stack, moved)

func has(item_id: int, tags: Array[Item.Tag] = []) -> bool:
	var variant_id := ItemVariantId.new(item_id, tags)
	for stack: ItemStack in _state.stacks:
		if _matches(stack, variant_id):
			return true
	return false

## Total quantity of the matching variant held across all its stacks (0 when absent).
func count(item_id: int, tags: Array[Item.Tag] = []) -> int:
	var variant_id := ItemVariantId.new(item_id, tags)
	var total := 0
	for stack: ItemStack in _state.stacks:
		if _matches(stack, variant_id):
			total += stack.quantity
	return total

## Read-only snapshot of the held stacks, for display.
func get_stacks() -> Array[ItemStack]:
	return _state.stacks.duplicate()

## Read-only snapshot of grid placements, parallel to [method get_stacks].
func get_placements() -> Array[StackPlacement]:
	return _state.placements.duplicate()

## The grid placement of [param stack], or null when absent or not a grid inventory.
func placement_of(stack: ItemStack) -> StackPlacement:
	var index := _state.stacks.find(stack)
	return _state.placements[index] if index != -1 and index < _state.placements.size() else null

## Whether [param stack] could sit at [param anchor] with [param rotation_steps] quarter
## turns — the validation half of [method move_stack], for placement previews.
func can_place(stack: ItemStack, anchor: Vector2i, rotation_steps: int = 0) -> bool:
	var grid_rule := capacity_rule as GridCapacityRule
	if grid_rule == null:
		return false
	var index := _state.stacks.find(stack)
	if index == -1 or index >= _state.placements.size() or stack.item_blueprint == null:
		return false
	var blocked := grid_rule.blocked_cell_set(_state, stack.item_blueprint.footprint_cells, index)
	return GridGeometry.fits(stack.item_blueprint.footprint_cells, anchor, rotation_steps, grid_rule.width, grid_rule.height, blocked)

## Moves [param stack] to [param anchor] with [param rotation_steps] quarter turns. Grid
## inventories only; false when the stack isn't held or the spot doesn't fit.
func move_stack(stack: ItemStack, anchor: Vector2i, rotation_steps: int = 0) -> bool:
	if not can_place(stack, anchor, rotation_steps):
		return false
	_state.placements[_state.stacks.find(stack)] = StackPlacement.new(anchor, rotation_steps)
	changed.emit(self)
	return true

## The stack whose footprint covers [param cell], or null. Grid inventories only.
func stack_at_cell(cell: Vector2i) -> ItemStack:
	for index in mini(_state.stacks.size(), _state.placements.size()):
		var stack: ItemStack = _state.stacks[index]
		if stack.item_blueprint == null:
			continue
		var placement: StackPlacement = _state.placements[index]
		if cell in GridGeometry.occupied_cells(stack.item_blueprint.footprint_cells, placement.anchor, placement.rotation_steps):
			return stack
	return null

## Capacity readout from the rule (e.g. "12 / 40"), or "" without a rule.
func describe_capacity() -> String:
	return capacity_rule.describe(_state) if capacity_rule != null else ""

func _matches(stack: ItemStack, variant_id: ItemVariantId) -> bool:
	return stack.item_blueprint != null and stack.variant_id.equals(variant_id)

# Names this inventory by its owning node (e.g. "Player") for log messages.
func _owner_label() -> String:
	var parent: Node = get_parent()
	return String(parent.name) if parent != null else "Unknown"

#endregion

#region State

## Swaps the inventory's runtime data for [param state]; the node then operates on it in place, so
## every add/remove lands on the shared [InventoryState] (e.g. a [PlayerState]'s). A fresh, empty
## [param state] inherits whatever the blueprint already seeded; a loaded one keeps its saved
## contents (the save wins). Apply the blueprint for defaults first, then bind to load.
func bind(state: InventoryState) -> void:
	if state == null:
		return
	if state.stacks.is_empty() and state.placements.is_empty():
		state.stacks = _state.stacks
		state.placements = _state.placements
	_state = state
	changed.emit(self)

#endregion

#region Blueprinting

func apply_blueprint(_blueprint: InventoryBlueprint) -> void:
	if not _blueprint:
		Log.error("Unable to apply blueprint; blueprint not found")
		return

	blueprint = _blueprint
	capacity_rule = _blueprint.capacity_rule

	# Build live stacks from the blueprint's authored templates so the inventory owns its own
	# quantities; the authored [ItemStack]s and their [ItemBlueprint]s stay shared and untouched.
	_state.stacks.clear()
	_state.placements.clear()
	var grid_rule := capacity_rule as GridCapacityRule
	for stack: ItemStack in _blueprint.item_stacks:
		if stack == null or stack.item_blueprint == null:
			continue
		if grid_rule != null:
			var placements := grid_rule.find_placements(_state, stack.item_blueprint, 1)
			if placements.is_empty():
				Log.warning("Skipped authored stack %s; no room in the grid" % stack.display_name)
				continue
			_state.placements.append(placements[0])
		_state.stacks.append(ItemStack.create(stack.item_blueprint, stack.quantity, stack.tags))

static func create(_blueprint: InventoryBlueprint) -> Inventory:
	if not _blueprint:
		Log.error("Blueprint required to create Inventory")
		return null

	var inventory: Inventory = SCENE.instantiate()
	inventory.apply_blueprint(_blueprint)
	return inventory

#endregion
