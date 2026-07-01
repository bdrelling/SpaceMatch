class_name StarshipStats
extends EntityStats
## A starship's stat profile — an [EntityStats] with typed sugar for the starship's stats. The
## [member EntityStats.values] dictionary of [StatPool]s is the storage and the math ([method EntityStats.add],
## [method EntityStats.get_stat]); these typed accessors are convenience over each pool's current value. A module
## authors one as its +/- contribution when slotted; summing the blocks of a starship's slotted modules
## ([method EntityStats.add]) gives the starship's stat profile.

var power: int:
	get: return get_named(&"power")
	set(value): set_named(&"power", value)
var speed: int:
	get: return get_named(&"speed")
	set(value): set_named(&"speed", value)
var cargo: int:
	get: return get_named(&"cargo")
	set(value): set_named(&"cargo", value)
var fuel: int:
	get: return get_named(&"fuel")
	set(value): set_named(&"fuel", value)
var armor: int:
	get: return get_named(&"armor")
	set(value): set_named(&"armor", value)
var defense: int:
	get: return get_named(&"defense")
	set(value): set_named(&"defense", value)
var sensors: int:
	get: return get_named(&"sensors")
	set(value): set_named(&"sensors", value)
var life_support: int:
	get: return get_named(&"life_support")
	set(value): set_named(&"life_support", value)
var weapons: int:
	get: return get_named(&"weapons")
	set(value): set_named(&"weapons", value)
var energy: int:
	get: return get_named(&"energy")
	set(value): set_named(&"energy", value)
## Bars of warp meter a starship can hold — its warp-bar capacity, granted by a warp-core module. Zero means the
## starship can't warp at all (no Jump, and warp tiles don't spawn for it). Summed from modules like any stat.
var warp_capacity: int:
	get: return get_named(&"warp_capacity")
	set(value): set_named(&"warp_capacity", value)
## Max hull this block contributes — the starship's health cap. A base block carries the starting hull (its pool
## authors current = maximum); a hull/armor module can add more. In a profile the value is the pool's ceiling, so
## summing blocks ([method EntityStats.add]) gives the effective max hull; the live hull depletes on the
## combatant's own pool (see [method Combatant.create]). Reads/writes the pool's maximum (and keeps current level
## with it, so a fresh ship reads full).
var health: int:
	get: return get_maximum_named(&"health")
	set(value):
		set_maximum_named(&"health", value)
		set_named(&"health", value)
