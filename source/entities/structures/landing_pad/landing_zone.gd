class_name LandingZone
extends Marker3D
## Marks a spot a [Starship] can land on — the transform is the touchdown point. Not tied
## to any structure: a [LandingPad] offers one, but so can any open ground (e.g. a town
## square). Hosts one ship at a time: [method receive] reserves the zone and starts the
## arrival's descent; the ship claims the zone on touchdown via [method land].

signal ship_landed(ship: Starship)
signal ship_departed(ship: Starship)

## The ship currently parked here, if any. A scene-authored child [Starship] is adopted as
## the occupant on ready.
var occupant: Starship

## The ship currently descending toward this zone, if any. Set for the whole approach so
## the zone can't be double-booked mid-arrival.
var incoming: Starship

func _ready() -> void:
	for child in get_children():
		var ship: Starship = child as Starship
		if ship != null:
			land(ship)
			break

func is_occupied() -> bool:
	return occupant != null

## Whether a new arrival can be sent here.
func is_available() -> bool:
	return occupant == null and incoming == null

## Accepts an arriving ship: reserves the zone, hosts the ship, and starts its descent.
## Returns false if the zone is already claimed.
func receive(ship: Starship) -> bool:
	if ship == null or not is_available():
		return false
	incoming = ship
	add_child(ship)
	ship.land_at(self)
	return true

## Claims the zone for [param ship]. Does nothing if the zone is already occupied or
## reserved for a different arrival.
func land(ship: Starship) -> void:
	if ship == null or occupant != null:
		return
	if incoming != null and incoming != ship:
		return
	incoming = null
	occupant = ship
	ship_landed.emit(ship)

## Releases the zone, returning the ship that departed (null if the zone was empty).
## Flying the ship away (and freeing it) is the caller's job.
func depart() -> Starship:
	if occupant == null:
		return null
	var ship: Starship = occupant
	occupant = null
	ship_departed.emit(ship)
	return ship
