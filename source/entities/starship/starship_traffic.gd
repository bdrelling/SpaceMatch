class_name StarshipTraffic
extends Node
## The starship side of the game's simulation: dispatches an arriving [Starship] to any
## open [LandingPad] it manages. Real scheduling waits on in-game time — for now every
## open pad fills at game start and refills the moment its ship departs.

## Pads this node manages. Wired in the level scene.
@export var landing_pads: Array[LandingPad] = []

## Hulls that can arrive; a dispatch picks one at random. Empty means no ships are
## available and nothing lands.
@export var fleet: Array[StarshipBlueprint] = []

func _ready() -> void:
	# Pads can be instanced siblings that aren't ready yet, so wiring waits for the scene.
	_start.call_deferred()

func _start() -> void:
	for pad: LandingPad in landing_pads:
		pad.landing_zone.ship_departed.connect(_on_ship_departed.bind(pad))
		_dispatch(pad)

func _dispatch(pad: LandingPad) -> void:
	if fleet.is_empty() or not pad.is_available():
		return
	var blueprint: StarshipBlueprint = fleet.pick_random()
	pad.receive(Starship.create(blueprint))

func _on_ship_departed(_ship: Starship, pad: LandingPad) -> void:
	_dispatch(pad)
