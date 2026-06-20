class_name GameSession
extends RefCounted
## The live runtime of one running game: holds a [GameState] and binds nodes to it. One per
## running game — never an autoload, so tests spin up fresh games and a future server can host
## several. Both the 3D game and the 2D Arcade drive the same GameSession over the same GameState.

var state: GameState

func _init(_state: GameState = null) -> void:
	state = _state if _state != null else GameState.new()

## A fresh single-player game — one empty [PlayerState] in the roster and an [OutpostState] with a
## single landing pad.
static func new_game() -> GameSession:
	var session := GameSession.new()
	session.state.players.append(PlayerState.new())
	session.state.outpost = _new_outpost()
	return session

static func _new_outpost() -> OutpostState:
	var outpost := OutpostState.new()
	outpost.landing_pads.append(LandingPadState.new())
	return outpost

## The player at [param player_index], or null when out of range.
func player(player_index: int) -> PlayerState:
	if player_index < 0 or player_index >= state.players.size():
		return null
	return state.players[player_index]

## Points [param inventory] (a node) at [param player_index]'s [InventoryState] so the node
## operates on that player's saved data in place. Apply the inventory's blueprint first for a new
## game's defaults; binding a loaded player keeps its saved contents.
func bind_inventory(inventory: Inventory, player_index: int = 0) -> void:
	var player_state := player(player_index)
	if inventory == null or player_state == null:
		return
	inventory.bind(player_state.inventory)

## Points [param clock] (a node) at the game's saved [GameClockState] so day and hour persist.
func bind_clock(clock: GameClock) -> void:
	if clock != null:
		clock.bind(state.clock)

## The saved state for the crafting station identified by [param id], or null when none is registered.
## A station and its arcade stage look theirs up by the same id, so both drive one state.
func crafting_station(id: StringName) -> CraftingStationState:
	if state.outpost == null:
		return null
	for station: CraftingStationState in state.outpost.crafting_stations:
		if station != null and station.id == id:
			return station
	return null

## Registers [param station] so later lookups by its id find it. No-op for a null station, a missing
## outpost, or an id already present.
func add_crafting_station(station: CraftingStationState) -> void:
	if station == null or state.outpost == null:
		return
	if crafting_station(station.id) != null:
		return
	state.outpost.crafting_stations.append(station)
