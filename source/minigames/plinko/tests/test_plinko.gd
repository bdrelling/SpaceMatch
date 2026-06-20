extends GdUnitTestSuite
## PlinkoMinigame: feeding scrap consumes one flat scrap from the bound inventory and drops a fixed
## spread of balls. A ball landing in a slot pays that slot's component; if the slot is unlocked the
## landing also changes its type, and if locked it just pays and holds. Matching all three slots on
## one type wins a damaged module. Locking a slot is a player tap. Instantiates the real scene so the
## board/canvas wiring runs too.

const _BALLS_PER_FEED := 2

const _SCRAP: ItemBlueprint = preload("res://resources/items/scrap/scrap_item_blueprint.tres")
const _WIRE: ItemBlueprint = preload("res://resources/items/components/wire_item_blueprint.tres")
const _TUBE: ItemBlueprint = preload("res://resources/items/components/tube_item_blueprint.tres")
const _PANEL: ItemBlueprint = preload("res://resources/items/components/panel_item_blueprint.tres")
const _MODULE: ItemBlueprint = preload("res://resources/items/modules/reactor_item_blueprint.tres")

func _make() -> PlinkoMinigame:
	var scene: PackedScene = load("res://minigames/plinko/plinko.tscn")
	var game: PlinkoMinigame = scene.instantiate()
	add_child(game)
	return game

func _inventory_with(amount: int) -> Inventory:
	var inventory := Inventory.new()
	add_child(inventory)
	inventory.add_variant(_SCRAP, [], amount)
	return inventory

## A recycle's ordered outputs as the board sees them: [wire, tube, panel, damaged module].
func _outputs() -> Array[ItemStack]:
	var no_tags: Array[Item.Tag] = []
	var damaged: Array[Item.Tag] = [Item.Tag.DAMAGED]
	var out: Array[ItemStack] = []
	out.append(ItemStack.create(_WIRE, 1, no_tags))
	out.append(ItemStack.create(_TUBE, 1, no_tags))
	out.append(ItemStack.create(_PANEL, 1, no_tags))
	out.append(ItemStack.create(_MODULE, 1, damaged))
	return out

func _board_with_recordings(produced: Array[ItemStack], jackpots: Array[ItemStack]) -> PlinkoBoard:
	var board := PlinkoBoard.new()
	board.recycled.connect(func(output: ItemStack) -> void: produced.append(output))
	board.jackpot.connect(func(output: ItemStack) -> void: jackpots.append(output))
	board.build(_outputs())
	add_child(board)
	return board

# --- Feeding consumes one scrap and drops a fixed spread of balls ---

func test_feeding_consumes_one_scrap_and_drops_balls() -> void:
	var game := _make()
	await await_idle_frame()
	var inventory := _inventory_with(3)
	game.bind_session(null, inventory)

	game._feed_scrap()

	assert_int(inventory.count(_SCRAP.id)).is_equal(2)
	assert_int(game._board._ball_container.get_child_count()).is_equal(_BALLS_PER_FEED)
	game.queue_free()
	inventory.queue_free()

func test_bind_session_seeds_scrap_into_an_empty_inventory() -> void:
	var game := _make()
	await await_idle_frame()
	var inventory := Inventory.new()
	add_child(inventory)

	game.bind_session(null, inventory)

	assert_int(inventory.count(_SCRAP.id)).is_greater(0)
	game.queue_free()
	inventory.queue_free()

func test_feeding_with_no_scrap_drops_nothing() -> void:
	var game := _make()
	await await_idle_frame()
	var inventory := Inventory.new()
	add_child(inventory)
	game.bind_session(null, inventory)
	inventory.remove(_SCRAP.id, 9999)

	game._feed_scrap()

	assert_int(game._board._ball_container.get_child_count()).is_equal(0)
	game.queue_free()
	inventory.queue_free()

# --- Slots: landing pays a component; lock holds the type; matching wins the module ---

func test_landing_on_an_unlocked_slot_pays_a_component() -> void:
	var produced: Array[ItemStack] = []
	var jackpots: Array[ItemStack] = []
	var board := _board_with_recordings(produced, jackpots)
	await await_idle_frame()

	board._on_slot_ball_landed(board._slots[0], PlinkoBall.create(_outputs()))

	assert_int(produced.size()).is_equal(1)
	assert_int(produced[0].item_blueprint.category).is_equal(Item.Category.COMPONENT)
	assert_int(jackpots.size()).is_equal(0)
	board.queue_free()

func test_landing_on_a_locked_slot_pays_without_changing_its_type() -> void:
	var produced: Array[ItemStack] = []
	var jackpots: Array[ItemStack] = []
	var board := _board_with_recordings(produced, jackpots)
	await await_idle_frame()

	var slot := board._slots[0]
	slot.output_index = 1  # tube
	slot.locked = true
	board._on_slot_ball_landed(slot, PlinkoBall.create(_outputs()))

	assert_int(produced[0].item_blueprint.id).is_equal(_TUBE.id)
	assert_int(slot.output_index).is_equal(1)
	assert_bool(slot.locked).is_true()
	board.queue_free()

func test_matching_all_three_slots_wins_a_damaged_module() -> void:
	var produced: Array[ItemStack] = []
	var jackpots: Array[ItemStack] = []
	var board := _board_with_recordings(produced, jackpots)
	await await_idle_frame()

	# All three locked on wire; the landing completes the match.
	for slot: PlinkoSlot in board._slots:
		slot.output_index = 0
		slot.locked = true
	board._on_slot_ball_landed(board._slots[0], PlinkoBall.create(_outputs()))

	assert_int(jackpots.size()).is_equal(1)
	assert_int(jackpots[0].item_blueprint.id).is_equal(_MODULE.id)
	assert_bool(jackpots[0].tags.has(Item.Tag.DAMAGED)).is_true()
	board.queue_free()

func test_tapping_a_slot_locks_and_unlocks_it() -> void:
	var produced: Array[ItemStack] = []
	var jackpots: Array[ItemStack] = []
	var board := _board_with_recordings(produced, jackpots)
	await await_idle_frame()

	var point := board.to_global(board._slots[1].position)
	assert_int(board.slot_index_at(point)).is_equal(1)
	board.lock_slot(1)
	assert_bool(board._slots[1].locked).is_true()
	board.lock_slot(1)
	assert_bool(board._slots[1].locked).is_false()
	board.queue_free()
